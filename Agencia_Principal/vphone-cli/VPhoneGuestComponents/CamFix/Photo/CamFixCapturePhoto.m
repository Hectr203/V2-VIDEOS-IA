// -[AVCapturePhotoOutput capturePhotoWithSettings:delegate:]: when the
// photo output is bound to our virtual camera, deliver a photo built from
// the shm frame instead of calling into the daemon's still pipeline.

#import "CamFixPrivate.h"

// MARK: - capturePhoto swizzle (modern + deprecated delegate paths)

static IMP cfx_orig_capturePhoto = NULL;

static void cfx_deliver_capturePhoto(id output, id delegate) {
  // Modern path used by any AVF client: build a real AVCapturePhoto from
  // the shm frame, tag it with our JPEG + CGImage so fileDataRepresentation
  // / CGImageRepresentation return our bytes, fire the modern delegate
  // didFinishProcessingPhoto:error:.
  // Falls back to the deprecated CMSampleBuffer delegate if the client
  // opts into it (only test harnesses do; production AVF clients implement
  // the modern method).
  SEL oldSel = NSSelectorFromString(
      @"captureOutput:didFinishProcessingPhotoSampleBuffer:previewPhotoSampleBuffer:resolvedSettings:bracketSettings:error:");
  if ([delegate respondsToSelector:oldSel]) {
    CMSampleBufferRef sbuf = cfx_build_cmsb();
    if (!sbuf) { cfxlog(@"[capturePhoto] build_cmsb returned NULL"); return; }
    cfxlog(@"[capturePhoto] dispatching deprecated didFinishProcessingPhotoSampleBuffer:");
    ((void (*)(id, SEL, id, CMSampleBufferRef, CMSampleBufferRef, id, id, id))objc_msgSend)(
        delegate,
        oldSel,
        output,
        sbuf,
        NULL,
        (id)nil,
        (id)nil,
        (id)nil);
    CFRelease(sbuf);
    return;
  }

  SEL S5 = @selector(captureOutput:didFinishProcessingPhoto:error:);
  if (![delegate respondsToSelector:S5]) {
    cfxlog(@"[capturePhoto] delegate implements neither modern nor deprecated method");
    return;
  }

  uint32_t w = 0, h = 0;
  IOSurfaceRef surf = cfx_build_iosurface_from_shm(&w, &h);
  if (!surf) { cfxlog(@"[capturePhoto] no IOSurface"); return; }

  // captureRequest = nil (no CAMCaptureEngine outside Camera.app). The
  // AVCapturePhoto init handles nil safely — objc_msgSend on nil returns 0
  // for the resolvedSettings / unresolvedSettings calls it makes during init.
  id photo = cfx_build_avcapturephoto_with_request(surf, w, h, nil);
  CFRelease(surf);
  if (!photo) { cfxlog(@"[capturePhoto] no AVCapturePhoto"); return; }

  NSData *jpeg = cfx_stamp_photo(photo);
  cfxlog(@"[capturePhoto] firing didFinishProcessingPhoto: with vcam photo (%lu bytes jpeg)",
         (unsigned long)jpeg.length);
  ((void (*)(id, SEL, id, id, id))objc_msgSend)(delegate, S5, output, photo, nil);
}

static void cfx_capturePhoto_hook(id self, SEL _cmd, id settings, id delegate) {
  cfxlog(@"[capturePhoto] self=%p settings=%@ delegate=%@",
         self, settings, delegate);
  BOOL forVcam = cfx_output_is_for_vcam(self);
  cfxlog(@"forVcam=%d", forVcam);

  if (!forVcam) {
    typedef void (*OrigFn)(id, SEL, id, id);
    ((OrigFn)cfx_orig_capturePhoto)(self, _cmd, settings, delegate);
    return;
  }
  __strong id retainedSelf = self;
  __strong id retainedDelegate = delegate;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    @autoreleasepool {
      cfx_deliver_capturePhoto(retainedSelf, retainedDelegate);
    }
  });
}

void cfx_install_capturePhoto_hook(void) {
  Class cls = NSClassFromString(@"AVCapturePhotoOutput");
  if (!cls) { cfxlog(@"AVCapturePhotoOutput missing"); return; }
  SEL sel = @selector(capturePhotoWithSettings:delegate:);
  Method m = class_getInstanceMethod(cls, sel);
  if (!m) { cfxlog(@"capturePhotoWithSettings:delegate: not found"); return; }
  cfx_orig_capturePhoto = method_setImplementation(m, (IMP)cfx_capturePhoto_hook);
  cfxlog(@"installed capturePhoto hook (orig=%p)", cfx_orig_capturePhoto);
}
