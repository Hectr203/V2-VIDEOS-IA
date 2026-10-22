// -[AVCaptureFigVideoDevice _setActiveFormat:...]: suppress the crash when
// the device is our virtual camera and the format argument is nil.

#import "CamFixPrivate.h"

// MARK: - _setActiveFormat: nil-format guard

static IMP cfx_orig_setActiveFormat = NULL;

// Signature: void(*)(id self, SEL _cmd, AVCaptureDeviceFormat *fmt,
//                    BOOL resetZoomAndFrameRates, NSString *preset)
static void cfx_setActiveFormat_hook(id self, SEL _cmd, id fmt,
                                       BOOL resetZoomAndFrameRates,
                                       NSString *preset) {
  if (!fmt) {
    NSString *uid = nil;
    @try { uid = [self valueForKey:@"uniqueID"]; } @catch (NSException *e) {}
    cfxlog(@"[setActiveFormat:nil] device.uid=%@ preset=%@", uid, preset);
    if ([uid isEqualToString:VCAM_UID]) {
      // Substitute the first available format from the device's -formats list.
      NSArray *fmts = nil;
      @try { fmts = [self valueForKey:@"formats"]; } @catch (NSException *e) {}
      if (fmts.count > 0) {
        fmt = fmts.firstObject;
        cfxlog(@"[setActiveFormat:] substituted first format: %@", fmt);
      } else {
        cfxlog(@"[setActiveFormat:] device.formats is empty — letting AVF throw");
      }
    }
  }
  typedef void (*OrigFn)(id, SEL, id, BOOL, NSString *);
  ((OrigFn)cfx_orig_setActiveFormat)(self, _cmd, fmt, resetZoomAndFrameRates, preset);
}

void cfx_install_setActiveFormat_hook(void) {
  Class cls = NSClassFromString(@"AVCaptureFigVideoDevice");
  if (!cls) { cfxlog(@"AVCaptureFigVideoDevice missing"); return; }
  SEL sel = NSSelectorFromString(
      @"_setActiveFormat:resetVideoZoomFactorAndMinMaxFrameDurations:sessionPreset:");
  Method m = class_getInstanceMethod(cls, sel);
  if (!m) {
    cfxlog(@"_setActiveFormat: method not in objc table");
    return;
  }
  cfx_orig_setActiveFormat =
      method_setImplementation(m, (IMP)cfx_setActiveFormat_hook);
  cfxlog(@"installed _setActiveFormat: hook (orig=%p)",
         cfx_orig_setActiveFormat);
}
