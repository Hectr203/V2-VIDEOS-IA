// Camera.app's shutter path: the moment-capture trio on AVCapturePhotoOutput
// and the CAMStillImageCaptureRequest stubs its capture engine reads.

#import "CamFixPrivate.h"

// MARK: - beginMomentCapture / commitMomentCapture hooks
//
// Camera.app uses -[AVCapturePhotoOutput beginMomentCaptureWithSettings:
// delegate:] (Live Photo path) when the user taps the shutter. The original
// implementation throws NSInvalidArgumentException because our daemon's
// photo XPC isn't backed by a real still pipeline.
//
// For our virtual camera, SKIP the original entirely. Just async-deliver
// a CMSampleBuffer to the delegate. We never call orig — so AVF's state
// stays clean and subsequent shutter taps don't compound corruption.

static IMP cfx_orig_beginMomentCapture = NULL;
static IMP cfx_orig_commitMomentCapture = NULL;
static IMP cfx_orig_cancelMomentCapture = NULL;

// Build a minimal AVCaptureResolvedPhotoSettings with just _uniqueID set.
// Bypasses the 32-arg +resolvedSettingsWith… factory (which crashes on
// nil dict args). CAMCaptureEngine's didFinishProcessingPhoto: only reads
// uniqueID off the resolvedSettings to match the pending request.

static id cfx_build_minimal_resolved(int64_t uid) {
  Class outerCls = NSClassFromString(@"AVCaptureResolvedPhotoSettings");
  Class innerCls = NSClassFromString(@"AVCaptureResolvedPhotoSettingsInternal");
  if (!outerCls || !innerCls) return nil;

  id outer = class_createInstance(outerCls, 0);
  id inner = class_createInstance(innerCls, 0);
  if (!outer || !inner) return nil;

  // uniqueID:q (int64_t)
  Ivar uidIvar = class_getInstanceVariable(innerCls, "uniqueID");
  if (uidIvar) {
    *(int64_t *)((char *)(__bridge void *)inner + ivar_getOffset(uidIvar)) = uid;
  }

  // Set photo + preview dimensions so dimension accessors return our size.
  // (Zero structs are technically safe but feed our real dims for realism.)
  struct cfx_dims2 { int32_t w, h; };
  struct cfx_dims2 photoDim = {1280, 720};
  const char *dimNames[] = {"photoDimensions", "previewDimensions", NULL};
  for (int i = 0; dimNames[i]; i++) {
    Ivar iv = class_getInstanceVariable(innerCls, dimNames[i]);
    if (iv) {
      *(struct cfx_dims2 *)((char *)(__bridge void *)inner + ivar_getOffset(iv))
          = photoDim;
    }
  }

  // NSArray-typed ivars should be empty arrays, not nil, so AVF callers
  // can safely send -count etc. The strong-default setter retains for an
  // MRC ivar and follows the declared ownership for an ARC one, so the
  // owner's dealloc balances it either way — a manual retain here would
  // leak once per resolved settings when the ivar is ARC strong.
  const char *arrayNames[] = {"photoManifest", "digitalFlashUserInterfaceRGBEstimate", NULL};
  for (int i = 0; arrayNames[i]; i++) {
    Ivar iv = class_getInstanceVariable(innerCls, arrayNames[i]);
    if (iv) object_setIvarWithStrongDefault(inner, iv, @[]);
  }

  // Wire outer._internal = inner; outer's dealloc releases it.
  Ivar internalIvar = class_getInstanceVariable(outerCls, "_internal");
  if (internalIvar) object_setIvarWithStrongDefault(outer, internalIvar, inner);

  return outer;
}

// We attach the uid via objc_setAssociatedObject before AVCapturePhoto's
// init calls -resolvedSettings on the captureRequest; the stub reads it.
static const void *CFX_ASSOC_UID_KEY = &CFX_ASSOC_UID_KEY;

// MARK: - CAMStillImageCaptureRequest stubs

static id cfx_stub_resolvedSettings(id self, SEL _cmd) {
  (void)_cmd;
  NSNumber *uidObj = objc_getAssociatedObject(self, CFX_ASSOC_UID_KEY);
  int64_t uid = uidObj.longLongValue;
  id r = cfx_build_minimal_resolved(uid);
  // Log pointer only — calling -description on a half-built obj crashes.
  cfxlog(@"[stub resolvedSettings] uid=%lld -> %p", uid, r);
  return r;
}

static id cfx_stub_unresolvedSettings(id self, SEL _cmd) {
  (void)self; (void)_cmd;
  return nil;
}

static BOOL cfx_stub_lensStabSupported(id self, SEL _cmd) {
  (void)self; (void)_cmd;
  return NO;
}

void cfx_install_capturerequest_stubs(void) {
  Class cls = NSClassFromString(@"CAMStillImageCaptureRequest");
  if (!cls) { cfxlog(@"CAMStillImageCaptureRequest missing"); return; }
  if (class_addMethod(
          cls,
          NSSelectorFromString(@"resolvedSettings"),
          (IMP)cfx_stub_resolvedSettings,
          "@@:")) {
    cfxlog(@"stubbed resolvedSettings on CAMStillImageCaptureRequest");
  }
  if (class_addMethod(
          cls,
          NSSelectorFromString(@"unresolvedSettings"),
          (IMP)cfx_stub_unresolvedSettings,
          "@@:")) {
    cfxlog(@"stubbed unresolvedSettings on CAMStillImageCaptureRequest");
  }
  if (class_addMethod(
          cls,
          NSSelectorFromString(@"lensStabilizationSupported"),
          (IMP)cfx_stub_lensStabSupported,
          "B@:")) {
    cfxlog(@"stubbed lensStabilizationSupported on CAMStillImageCaptureRequest");
  }
}

// MARK: - drive the capture state machine

static void cfx_drive_capture(id output, id delegate, id settings) {
  // Extract uniqueID from AVMomentCaptureSettings.
  int64_t uid = 0;
  @try {
    NSNumber *n = [settings valueForKey:@"uniqueID"];
    uid = n.longLongValue;
  } @catch (NSException *e) {}
  cfxlog(@"[drive] uid=%lld settings=%@", uid, [settings class]);

  // Look up the real captureRequest from CAMCaptureEngine's internal
  // registry FIRST. When the user tapped the shutter, CAMCaptureEngine
  // registered a CAMCaptureRequestInfo keyed by uid (the
  // _resultsQueueRegisteredStillImageRequests ivar). Its `request` property
  // is the AVCaptureRequest we need to pass as the `captureRequest:` arg
  // to the AVCapturePhoto init — without it, CAMCaptureEngine's
  // didFinishProcessing handler can't match the photo to a pending
  // request and drops it.
  id captureRequest = nil;
  @try {
    id reqDict = [delegate valueForKey:@"_resultsQueueRegisteredStillImageRequests"];
    if ([reqDict isKindOfClass:[NSDictionary class]]) {
      id info = ((NSDictionary *)reqDict)[@(uid)];
      if (info) {
        id stillReq = [info valueForKey:@"request"];
        cfxlog(@"[drive] CAMStillImageCaptureRequest=%p for uid=%lld",
               stillReq, uid);
        // Tag the captureRequest with the uid so the resolvedSettings stub
        // (which has no parameter context) can recover it.
        objc_setAssociatedObject(stillReq, CFX_ASSOC_UID_KEY, @(uid),
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        captureRequest = stillReq;
      } else {
        cfxlog(@"[drive] no CAMCaptureRequestInfo for uid=%lld; keys=%@",
               uid, ((NSDictionary *)reqDict).allKeys);
      }
    }
  } @catch (NSException *e) {
    cfxlog(@"[drive] registry lookup threw: %@", e);
  }

  // Build IOSurface from shm.
  uint32_t w = 0, h = 0;
  IOSurfaceRef surf = cfx_build_iosurface_from_shm(&w, &h);
  if (!surf || !w || !h) {
    cfxlog(@"[drive] no IOSurface — falling back to error finish");
    NSError *err = [NSError errorWithDomain:AVFoundationErrorDomain
                                       code:-11800
                                   userInfo:@{NSLocalizedDescriptionKey:@"Unable to take the photo. Try again."}];
    SEL finishSel = @selector(captureOutput:didFinishCaptureForResolvedSettings:error:);
    if ([delegate respondsToSelector:finishSel]) {
      ((void (*)(id, SEL, id, id, id))objc_msgSend)(delegate, finishSel, output, nil, err);
    }
    if (surf) CFRelease(surf);
    return;
  }
  cfxlog(@"[drive] IOSurface %ux%u built", w, h);

  // Build AVCapturePhoto WITH the real captureRequest.
  id photo = cfx_build_avcapturephoto_with_request(surf, w, h, captureRequest);
  CFRelease(surf);  // photo retains it
  if (!photo) {
    cfxlog(@"[drive] no AVCapturePhoto — abort");
    return;
  }

  // Stamp it with our JPEG so fileDataRepresentation returns our bytes.
  NSData *jpeg = cfx_stamp_photo(photo);
  cfxlog(@"[drive] photo stamped jpeg=%lu bytes", (unsigned long)jpeg.length);

  // Fire the FULL standard delegate sequence. CAMCaptureEngine tracks
  // a _receivedCallbacks set per uid; until ALL expected callbacks
  // arrive, the request stays in
  // _resultsQueueRegisteredStillImageRequests and the engine refuses
  // to start new captures (manifests as "shutter stops working after
  // N taps"). We now have a real resolvedSettings, so we can fire the
  // will/did pre-callbacks too.
  id resolvedForFinish = nil;
  @try {
    resolvedForFinish = [photo valueForKey:@"resolvedSettings"];
  } @catch (NSException *e) {
    cfxlog(@"[drive] photo.resolvedSettings threw: %@", e);
  }
  SEL S1 = @selector(captureOutput:willBeginCaptureBeforeResolvingSettingsForUniqueID:);
  SEL S2 = @selector(captureOutput:willBeginCaptureForResolvedSettings:);
  SEL S3 = @selector(captureOutput:willCapturePhotoForResolvedSettings:);
  SEL S4 = @selector(captureOutput:didCapturePhotoForResolvedSettings:);
  SEL S5 = @selector(captureOutput:didFinishProcessingPhoto:error:);
  SEL S6 = @selector(captureOutput:didFinishCaptureForResolvedSettings:error:);
  SEL Sfinish = NSSelectorFromString(@"_didFinishStillImageCaptureForUniqueID:error:");
  if ([delegate respondsToSelector:S1]) {
    cfxlog(@"[drive] -> willBeginCaptureBefore… uid=%lld", uid);
    ((void (*)(id, SEL, id, int64_t))objc_msgSend)(delegate, S1, output, uid);
  }
  if (resolvedForFinish && [delegate respondsToSelector:S2]) {
    cfxlog(@"[drive] -> willBeginCaptureForResolvedSettings:");
    ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, S2, output, resolvedForFinish);
  }
  if (resolvedForFinish && [delegate respondsToSelector:S3]) {
    cfxlog(@"[drive] -> willCapturePhotoForResolvedSettings:");
    ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, S3, output, resolvedForFinish);
  }
  if (resolvedForFinish && [delegate respondsToSelector:S4]) {
    cfxlog(@"[drive] -> didCapturePhotoForResolvedSettings:");
    ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, S4, output, resolvedForFinish);
  }
  if ([delegate respondsToSelector:S5]) {
    cfxlog(@"[drive] -> didFinishProcessingPhoto:error:");
    ((void (*)(id, SEL, id, id, id))objc_msgSend)(delegate, S5, output, photo, nil);
  }
  if ([delegate respondsToSelector:S6]) {
    cfxlog(@"[drive] -> didFinishCapture resolved=%p", resolvedForFinish);
    ((void (*)(id, SEL, id, id, id))objc_msgSend)(
        delegate, S6, output, resolvedForFinish, nil);
  }
  if ([delegate respondsToSelector:Sfinish]) {
    cfxlog(@"[drive] -> _didFinishStillImageCaptureForUniqueID:%lld", uid);
    ((void (*)(id, SEL, int64_t, id))objc_msgSend)(delegate, Sfinish, uid, nil);
  }

  // Signal that the output is ready for the NEXT capture request. AVF's
  // photo output is a 2-deep pipeline — Camera.app's shutter stays
  // disabled until this fires for each in-flight capture.
  SEL Sready = NSSelectorFromString(@"captureOutput:readyForResponsiveRequestAfterResolvedSettings:");
  if (resolvedForFinish && [delegate respondsToSelector:Sready]) {
    cfxlog(@"[drive] -> readyForResponsiveRequestAfterResolvedSettings:");
    ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, Sready, output, resolvedForFinish);
  }

  cfxlog(@"[drive] sequence complete");
}

// We stash (delegate, settings) on the AVCapturePhotoOutput at begin time,
// keyed by the settings' uniqueID, so the commit hook can drive the capture
// once CAMCaptureEngine has registered the request in its internal dict.
// The photo output is a two-deep pipeline, so a second begin can arrive
// before the first commit; keying keeps each commit on its own settings.
// Commit and cancel take the entry out, so the output does not keep its
// delegate (which owns the output) alive after the capture.
static const void *CFX_ASSOC_PENDING_KEY = &CFX_ASSOC_PENDING_KEY;

static NSNumber *cfx_settings_uid(id settings) {
  @try {
    return @([[settings valueForKey:@"uniqueID"] longLongValue]);
  } @catch (NSException *e) {
    return @0;
  }
}

static void cfx_pending_put(id output, id settings, id delegate) {
  @synchronized(output) {
    NSMutableDictionary *pending = objc_getAssociatedObject(output, CFX_ASSOC_PENDING_KEY);
    if (!pending) {
      pending = [NSMutableDictionary dictionary];
      objc_setAssociatedObject(output, CFX_ASSOC_PENDING_KEY, pending,
                               OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    pending[cfx_settings_uid(settings)] = @[ delegate, settings ?: [NSNull null] ];
  }
}

// Takes the entry for uid out. A commit falls back to the only pending
// entry when the uid does not match, which is what the output-wide stash
// did before; a cancel removes an exact match only.
static NSArray *cfx_pending_take(id output, intptr_t uid, BOOL fallBackToOnly) {
  @synchronized(output) {
    NSMutableDictionary *pending = objc_getAssociatedObject(output, CFX_ASSOC_PENDING_KEY);
    NSNumber *key = @((long long)uid);
    NSArray *entry = pending[key];
    if (!entry && fallBackToOnly && pending.count == 1) {
      key = pending.allKeys.firstObject;
      entry = pending[key];
    }
    if (entry) [pending removeObjectForKey:key];
    return entry;
  }
}

static void cfx_beginMomentCapture_hook(id self, SEL _cmd, id settings, id delegate) {
  BOOL forVcam = cfx_output_is_for_vcam(self);
  cfxlog(@"[beginMomentCapture] forVcam=%d delegate=%@", forVcam, delegate);
  if (!forVcam) {
    typedef void (*OrigFn)(id, SEL, id, id);
    ((OrigFn)cfx_orig_beginMomentCapture)(self, _cmd, settings, delegate);
    return;
  }
  // SKIP orig — it throws for our session. Just stash the delegate +
  // settings; commit will drive the photo delivery once CAMCaptureEngine
  // has registered the captureRequest internally.
  if (delegate) cfx_pending_put(self, settings, delegate);
}

// NOTE: uniqueID is a pointer-sized integer (not an NSUUID *). Declaring
// it as `id` would cause ARC to retain it on entry, dereferencing the
// integer-as-isa and segfaulting. Use intptr_t to skip the retain.

static void cfx_commitMomentCapture_hook(id self, SEL _cmd, intptr_t uniqueID) {
  BOOL forVcam = cfx_output_is_for_vcam(self);
  cfxlog(@"[commitMomentCapture] forVcam=%d uniqueID=%ld", forVcam, (long)uniqueID);
  if (!forVcam) {
    typedef void (*OrigFn)(id, SEL, intptr_t);
    ((OrigFn)cfx_orig_commitMomentCapture)(self, _cmd, uniqueID);
    return;
  }
  // SKIP orig (would throw) and drive the synthesized photo delivery
  // here, where CAMCaptureEngine has already registered its
  // CAMCaptureRequestInfo for this uid.
  NSArray *entry = cfx_pending_take(self, uniqueID, YES);
  if (!entry) {
    cfxlog(@"[commit] no stashed delegate — was begin called?");
    return;
  }
  __strong id retainedSelf = self;
  __strong id retainedDelegate = entry[0];
  __strong id retainedSettings = entry[1] == [NSNull null] ? nil : entry[1];
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    @autoreleasepool {
      cfx_drive_capture(retainedSelf, retainedDelegate, retainedSettings);
    }
  });
}

static void cfx_cancelMomentCapture_hook(id self, SEL _cmd, intptr_t uniqueID) {
  BOOL forVcam = cfx_output_is_for_vcam(self);
  cfxlog(@"[cancelMomentCapture] forVcam=%d uniqueID=0x%lx", forVcam, (long)uniqueID);
  if (!forVcam) {
    typedef void (*OrigFn)(id, SEL, intptr_t);
    ((OrigFn)cfx_orig_cancelMomentCapture)(self, _cmd, uniqueID);
    return;
  }
  // Orig throws (the begin was a no-op so there is no live moment to
  // cancel). CAMCaptureEngine drives this when it decides the capture is
  // stale; just drop what begin stashed.
  (void)cfx_pending_take(self, uniqueID, NO);
}

void cfx_install_moment_capture_hooks(void) {
  Class cls = NSClassFromString(@"AVCapturePhotoOutput");
  if (!cls) return;
  SEL b = @selector(beginMomentCaptureWithSettings:delegate:);
  SEL c = NSSelectorFromString(@"commitMomentCaptureToPhotoWithUniqueID:");
  SEL x = NSSelectorFromString(@"cancelMomentCaptureWithUniqueID:");
  Method mb = class_getInstanceMethod(cls, b);
  Method mc = class_getInstanceMethod(cls, c);
  Method mx = class_getInstanceMethod(cls, x);
  if (mb) {
    cfx_orig_beginMomentCapture =
        method_setImplementation(mb, (IMP)cfx_beginMomentCapture_hook);
    cfxlog(@"installed beginMomentCapture hook");
  }
  if (mc) {
    cfx_orig_commitMomentCapture =
        method_setImplementation(mc, (IMP)cfx_commitMomentCapture_hook);
    cfxlog(@"installed commitMomentCapture hook");
  }
  if (mx) {
    cfx_orig_cancelMomentCapture =
        method_setImplementation(mx, (IMP)cfx_cancelMomentCapture_hook);
    cfxlog(@"installed cancelMomentCapture hook");
  }
}
