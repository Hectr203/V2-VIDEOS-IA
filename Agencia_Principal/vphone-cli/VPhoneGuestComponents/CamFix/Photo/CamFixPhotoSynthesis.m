// AVCapturePhoto objects built from the shm frame, and the
// fileDataRepresentation / CGImageRepresentation hooks that hand back the
// bytes stamped onto them.

#import "CamFixPrivate.h"

// Associated-object keys the representation hooks use to recognize "our"
// photos without a global dict.
static const void *CFX_ASSOC_JPEG_KEY = &CFX_ASSOC_JPEG_KEY;
static const void *CFX_ASSOC_CGIMG_KEY = &CFX_ASSOC_CGIMG_KEY;

// Tag a synthesized photo with our JPEG + CGImage so fileDataRepresentation
// / CGImageRepresentation return our bytes. Returns the JPEG so the caller
// can log its size.
NSData *cfx_stamp_photo(id photo) {
  // One frame for both representations, so they show the same picture.
  CGImageRef cgImg = cfx_build_cgimage_from_shm();
  NSData *jpeg = cfx_jpeg_from_cgimage(cgImg);
  if (jpeg) objc_setAssociatedObject(
      photo,
      CFX_ASSOC_JPEG_KEY,
      jpeg,
      OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  if (cgImg) {
    objc_setAssociatedObject(
        photo,
        CFX_ASSOC_CGIMG_KEY,
        (__bridge id)cgImg,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    CGImageRelease(cgImg);
  }
  return jpeg;
}

// MARK: - Version-agnostic invocation helpers
//
// AVCapturePhoto's designated init and AVCaptureResolvedPhotoSettings'
// factory each take 25+ arguments. The selectors are gigantic strings and
// Apple has been known to add/remove arguments between iOS revisions
// (which silently moves every later arg's positional index). To avoid
// rewriting every libcamfix release against a fixed signature, the
// builders below look up the selector by PREFIX at runtime and fill
// arguments by LABEL — the actual selector component names like
// "photoSurface" or "uniqueID" — so a future arg insertion just gets
// nil/zero in that slot without breaking the rest.

// Walk class_copyMethodList for `cls` (or its metaclass when looking for
// class methods) and return the selector with the most colons that starts
// with `prefix`. Returns NULL if nothing matches.
static SEL cfx_find_selector_by_prefix(
    Class cls,
    NSString *prefix,
    BOOL classMethod) {
  if (!cls || !prefix.length) return NULL;
  Class c = classMethod ? object_getClass(cls) : cls;
  unsigned int n = 0;
  Method *methods = class_copyMethodList(c, &n);
  if (!methods) return NULL;
  SEL best = NULL;
  NSUInteger bestArgs = 0;
  for (unsigned int i = 0; i < n; i++) {
    SEL s = method_getName(methods[i]);
    NSString *name = NSStringFromSelector(s);
    if (![name hasPrefix:prefix]) continue;
    NSUInteger colons = 0;
    for (NSUInteger j = 0; j < name.length; j++) {
      if ([name characterAtIndex:j] == ':') colons++;
    }
    if (colons > bestArgs) {
      bestArgs = colons;
      best = s;
    }
  }
  free(methods);
  return best;
}

// Normalize the first selector component to a canonical label. Apple
// init/factory selectors start with "initWithX:" / "resolvedSettingsWithX:";
// the helper-side label dictionary keys are just "X" (camelCase). Strips
// the prefix and lowercases the first character of the remainder.
static NSString *cfx_normalize_first_label(NSString *label) {
  for (NSString *prefix in @[@"initWith", @"resolvedSettingsWith"]) {
    if ([label hasPrefix:prefix] && label.length > prefix.length) {
      NSString *rest = [label substringFromIndex:prefix.length];
      return [[[rest substringToIndex:1] lowercaseString]
          stringByAppendingString:[rest substringFromIndex:1]];
    }
  }
  return label;
}

// Resolver block: called once per method argument with the canonical label
// (e.g. "photoSurface") and the runtime type encoding. The block decides
// whether and what to write into `outBuf` (already zeroed). If the block
// doesn't recognize the label, leave outBuf alone — nil for objects,
// zeroed bytes for structs/primitives.
typedef void (^cfx_arg_resolver_t)(
    NSString *label,
    const char *typeEnc,
    void *outBuf);

// Build + invoke `[target selector]` with arguments filled by `resolver`.
// Works whether `target` is an alloc'd instance (for inits) or a Class
// (for class-method factories). Returns the result if it's an object
// return type, nil otherwise.
static id cfx_invoke_with_labeled_args(
    id target,
    SEL selector,
    cfx_arg_resolver_t resolver) {
  NSMethodSignature *sig = nil;
  @try { sig = [target methodSignatureForSelector:selector]; }
  @catch (NSException *e) { return nil; }
  if (!sig) return nil;

  NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
  [inv setTarget:target];
  [inv setSelector:selector];

  NSArray<NSString *> *parts =
      [NSStringFromSelector(selector) componentsSeparatedByString:@":"];
  NSUInteger argCount = sig.numberOfArguments - 2;  // -2 for self + _cmd
  for (NSUInteger i = 0; i < argCount; i++) {
    NSString *raw = i < parts.count ? parts[i] : @"";
    NSString *label = (i == 0) ? cfx_normalize_first_label(raw) : raw;

    const char *typeEnc = [sig getArgumentTypeAtIndex:i + 2];
    NSUInteger argSize = 0, argAlign = 0;
    NSGetSizeAndAlignment(typeEnc, &argSize, &argAlign);
    if (argSize == 0) continue;

    // alloca on arm64 returns a 16-byte-aligned buffer; argSize <= 64 in
    // practice for everything Apple uses here (CMTimeRange is 48 bytes).
    void *buf = alloca(argSize);
    memset(buf, 0, argSize);
    if (resolver) resolver(label, typeEnc, buf);
    [inv setArgument:buf atIndex:i + 2];
  }

  @try {
    [inv invoke];
  } @catch (NSException *e) {
    cfxlog(@"invoke %@ threw: %@", NSStringFromSelector(selector), e);
    return nil;
  }

  if (sig.methodReturnLength > 0 &&
      sig.methodReturnType[0] == '@') {
    __unsafe_unretained id result = nil;
    [inv getReturnValue:&result];
    return result;
  }
  return nil;
}

// MARK: - AVCapturePhoto / Resolved settings synthesis

id cfx_build_avcapturephoto_with_request(IOSurfaceRef surf,
                                         uint32_t w, uint32_t h,
                                         id captureRequest) {
  Class cls = NSClassFromString(@"AVCapturePhoto");
  if (!cls) return nil;
  id alloc_obj = [cls alloc];
  if (!alloc_obj) return nil;

  // Discover the designated init at runtime. Apple may add/remove args
  // between iOS releases; we anchor on the leading components and accept
  // whatever the longest matching selector is.
  SEL initSel = cfx_find_selector_by_prefix(cls, @"initWithTimestamp:",
                                            /*classMethod*/NO);
  if (!initSel) { cfxlog(@"photo: no init selector found"); return nil; }

  CMTime ts = CMClockGetTime(CMClockGetHostTimeClock());
  CGSize sz = CGSizeMake((CGFloat)w, (CGFloat)h);
  NSString *fileType = @"public.jpeg";
  NSDictionary *meta = @{};
  NSString *deviceType = @"AVCaptureDeviceTypeBuiltInWideAngleCamera";

  id result = cfx_invoke_with_labeled_args(
      alloc_obj, initSel,
      ^(NSString *label, const char *typeEnc, void *out) {
        if ([label isEqualToString:@"timestamp"]) {
          *(CMTime *)out = ts;
        } else if ([label isEqualToString:@"photoSurface"]) {
          *(IOSurfaceRef *)out = surf;
        } else if ([label isEqualToString:@"photoSurfaceSize"]) {
          *(CGSize *)out = sz;
        } else if ([label isEqualToString:@"processedFileType"]) {
          *(__unsafe_unretained id *)out = fileType;
        } else if ([label isEqualToString:@"metadata"]) {
          *(__unsafe_unretained id *)out = meta;
        } else if ([label isEqualToString:@"captureRequest"]) {
          *(__unsafe_unretained id *)out = captureRequest;
        } else if ([label isEqualToString:@"sequenceCount"]
                || [label isEqualToString:@"photoCount"]) {
          *(NSInteger *)out = 1;
        } else if ([label isEqualToString:@"sourceDeviceType"]) {
          *(__unsafe_unretained id *)out = deviceType;
        }
        // Every other arg (preview/thumbnail/depth/portrait/hair/skin/
        // teeth/glasses/constantColor surfaces + their metadata dicts,
        // bracketSettings, expectedPhotoProcessingFlags, etc.) stays
        // zero/nil — works for both Camera.app (with non-nil
        // captureRequest) and standalone AVF clients (nil).
      });
  if (result) {
    cfxlog(@"AVCapturePhoto built: %p (captureRequest=%p, sel=%@)",
           result,
           captureRequest,
           NSStringFromSelector(initSel));
  }
  return result;
}

// MARK: - fileDataRepresentation / CGImageRepresentation hooks

static IMP cfx_orig_fileDataRep = NULL;
static IMP cfx_orig_cgImageRep = NULL;

static NSData *cfx_fileDataRep_hook(id self, SEL _cmd) {
  NSData *ours = objc_getAssociatedObject(self, CFX_ASSOC_JPEG_KEY);
  if (ours) {
    cfxlog(@"[fileDataRep] returning vcam jpeg (%lu bytes)", (unsigned long)ours.length);
    return ours;
  }
  typedef NSData *(*OrigFn)(id, SEL);
  return ((OrigFn)cfx_orig_fileDataRep)(self, _cmd);
}

static CGImageRef cfx_cgImageRep_hook(id self, SEL _cmd) {
  id wrap = objc_getAssociatedObject(self, CFX_ASSOC_CGIMG_KEY);
  if (wrap) {
    CGImageRef img = (__bridge CGImageRef)wrap;
    cfxlog(@"[cgImageRep] returning vcam CGImage");
    return img;
  }
  typedef CGImageRef (*OrigFn)(id, SEL);
  return ((OrigFn)cfx_orig_cgImageRep)(self, _cmd);
}

void cfx_install_photo_representation_hooks(void) {
  Class cls = NSClassFromString(@"AVCapturePhoto");
  if (!cls) return;
  Method m1 = class_getInstanceMethod(cls, @selector(fileDataRepresentation));
  Method m2 = class_getInstanceMethod(cls, @selector(CGImageRepresentation));
  if (m1) {
    cfx_orig_fileDataRep = method_setImplementation(m1, (IMP)cfx_fileDataRep_hook);
    cfxlog(@"installed fileDataRepresentation hook");
  }
  if (m2) {
    cfx_orig_cgImageRep = method_setImplementation(m2, (IMP)cfx_cgImageRep_hook);
    cfxlog(@"installed CGImageRepresentation hook");
  }
}
