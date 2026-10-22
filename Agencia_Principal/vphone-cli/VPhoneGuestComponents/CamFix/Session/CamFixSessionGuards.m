// AVCaptureSession state guards and getter lies that keep a vcam-bound
// session live, plus the session start and device input diagnostics.

#import "CamFixPrivate.h"

// MARK: - AVCaptureSession state guards
//
// After ~4-5s of no real sample buffer flow on the AVCaptureSession's
// preview connection, Camera.app's session transitions to
// "interrupted" / not-running and disables the shutter. We bypass the
// daemon's preview pipeline (we feed CALayer.contents directly), so
// no sample buffers ever flow.
//
// Two guards on AVCaptureSession for our vcam-bound sessions:
//   1. -[AVCaptureSession _setRunning:NO]   → swallow (stay running)
//   2. -[AVCaptureSession _setInterrupted:YES withReason:interruptor:] → swallow

static IMP cfx_orig_setRunning = NULL;
static IMP cfx_orig_setInterrupted = NULL;

// Diagnoses why a vcam session never reaches the daemon's graph builder:
// logs what the client thinks its session looks like at start time.
static void cfx_log_session_start(AVCaptureSession *session) {
  @try {
    NSMutableArray *lines = [NSMutableArray array];
    [lines addObject:[NSString stringWithFormat:@"inputs=%lu",
                      (unsigned long)session.inputs.count]];
    for (AVCaptureInput *inp in session.inputs) {
      NSString *uid = nil;
      if ([inp isKindOfClass:[AVCaptureDeviceInput class]]) {
        uid = ((AVCaptureDeviceInput *)inp).device.uniqueID;
      }
      [lines addObject:[NSString stringWithFormat:@"input %@ cls=%@ ports=%lu",
                        uid ?: @"?",
                        NSStringFromClass([inp class]),
                        (unsigned long)inp.ports.count]];
    }
    for (AVCaptureOutput *outp in session.outputs) {
      BOOL anyEnabled = NO;
      NSUInteger videoConns = 0;
      for (AVCaptureConnection *c in outp.connections) {
        if (c.enabled || c.active) anyEnabled = YES;
        for (AVCaptureInputPort *port in c.inputPorts) {
          if ([port.mediaType isEqualToString:AVMediaTypeVideo]) {
            videoConns++;
            break;
          }
        }
      }
      [lines addObject:[NSString stringWithFormat:@"output %@ conns=%lu video=%lu anyEnabled/Active=%d",
                        NSStringFromClass([outp class]),
                        (unsigned long)outp.connections.count,
                        (unsigned long)videoConns,
                        anyEnabled]];
    }
    cfxlog(@"[session start] %p %@", session, [lines componentsJoinedByString:@" | "]);
  } @catch (NSException *e) {
    cfxlog(@"[session start] dump exception: %@", e);
  }
}

static void cfx_session_setRunning_hook(id self, SEL _cmd, BOOL running) {
  if (running && cfx_session_is_for_vcam(self)) {
    cfx_log_session_start(self);
    cfx_track_vcam_session(self);
    // Only a process with a running vcam session can have a preview layer
    // to find.
    cfx_start_scan_timer();
  }
  if (!running && cfx_session_is_for_vcam(self)) {
    cfxlog(@"[session _setRunning:NO] suppressed for vcam session %p", self);
    return;
  }
  typedef void (*OrigFn)(id, SEL, BOOL);
  ((OrigFn)cfx_orig_setRunning)(self, _cmd, running);
}

static void cfx_session_setInterrupted_hook(id self, SEL _cmd,
                                              BOOL interrupted,
                                              long reason,
                                              id interruptor) {
  if (interrupted && cfx_session_is_for_vcam(self)) {
    cfxlog(@"[session _setInterrupted:YES reason=%ld] suppressed for vcam session %p",
           reason, self);
    return;
  }
  typedef void (*OrigFn)(id, SEL, BOOL, long, id);
  ((OrigFn)cfx_orig_setInterrupted)(self, _cmd, interrupted, reason, interruptor);
}

void cfx_install_session_guards(void) {
  Class cls = NSClassFromString(@"AVCaptureSession");
  if (!cls) { cfxlog(@"AVCaptureSession missing"); return; }
  SEL s1 = NSSelectorFromString(@"_setRunning:");
  SEL s2 = NSSelectorFromString(@"_setInterrupted:withReason:interruptor:");
  Method m1 = class_getInstanceMethod(cls, s1);
  Method m2 = class_getInstanceMethod(cls, s2);
  if (m1) {
    cfx_orig_setRunning = method_setImplementation(m1, (IMP)cfx_session_setRunning_hook);
    cfxlog(@"installed _setRunning: hook");
  } else {
    cfxlog(@"_setRunning: not in objc table");
    // Without the hook nothing would start the scan: keep the old
    // always-on fallback.
    cfx_start_scan_timer();
  }
  if (m2) {
    cfx_orig_setInterrupted = method_setImplementation(m2, (IMP)cfx_session_setInterrupted_hook);
    cfxlog(@"installed _setInterrupted: hook");
  } else {
    cfxlog(@"_setInterrupted: not in objc table");
  }
}

// MARK: - device input / port diagnostics
//
// A vcam session that never reaches startRunning usually dies at addInput:
// because the client-side device object has no ports (streams missing from
// the remote source copy). Log the port count at input creation and the
// app's own canAddInput: checks.

static IMP cfx_orig_dvinput_init = NULL;
static IMP cfx_orig_canAddInput = NULL;

__attribute__((ns_returns_retained))
static id cfx_dvinput_init_hook(id self, SEL _cmd, AVCaptureDevice *device, NSError **err) {
  typedef id (*Fn)(id, SEL, AVCaptureDevice *, NSError **);
  id ret = ((Fn)cfx_orig_dvinput_init)(self, _cmd, device, err);
  if ([device.uniqueID isEqualToString:VCAM_UID]) {
    cfxlog(@"[DeviceInput init] device=%@ ports=%lu err=%@",
           device.uniqueID,
           (unsigned long)((AVCaptureDeviceInput *)ret).ports.count,
           err && *err ? *err : nil);
  }
  return ret;
}

static BOOL cfx_canAddInput_hook(id self, SEL _cmd, AVCaptureInput *input) {
  typedef BOOL (*Fn)(id, SEL, AVCaptureInput *);
  BOOL ret = ((Fn)cfx_orig_canAddInput)(self, _cmd, input);
  if ([input isKindOfClass:[AVCaptureDeviceInput class]] &&
      [((AVCaptureDeviceInput *)input).device.uniqueID isEqualToString:VCAM_UID]) {
    cfxlog(@"[canAddInput:%@] -> %d", VCAM_UID, ret);
  }
  return ret;
}

void cfx_install_input_diagnostics(void) {
  Class cls = NSClassFromString(@"AVCaptureDeviceInput");
  Method m = cls ? class_getInstanceMethod(cls, @selector(initWithDevice:error:)) : NULL;
  if (m) {
    cfx_orig_dvinput_init = method_setImplementation(m, (IMP)cfx_dvinput_init_hook);
    cfxlog(@"installed DeviceInput init diag");
  }
  Class sessCls = NSClassFromString(@"AVCaptureSession");
  Method m2 = sessCls ? class_getInstanceMethod(sessCls, @selector(canAddInput:)) : NULL;
  if (m2) {
    cfx_orig_canAddInput = method_setImplementation(m2, (IMP)cfx_canAddInput_hook);
    cfxlog(@"installed canAddInput diag");
  }
}

// MARK: - AVCaptureSession state GETTER lies
//
// If Camera.app polls -isRunning / -isInterrupted in its UI loop and
// reacts to a transition (no-frames timer or similar), we can lie to
// keep the UI in "live preview" mode.

static IMP cfx_orig_isRunning = NULL;
static IMP cfx_orig_isInterrupted = NULL;
static int cfx_isRunning_logged = 0;
static int cfx_isInterrupted_logged = 0;

static BOOL cfx_session_isRunning_hook(id self, SEL _cmd) {
  typedef BOOL (*Fn)(id, SEL);
  BOOL real = ((Fn)cfx_orig_isRunning)(self, _cmd);
  if (cfx_session_is_for_vcam(self)) {
    cfx_track_vcam_session(self);
    if (cfx_isRunning_logged < 3) {
      cfxlog(@"[isRunning] real=%d -> forcing YES (session=%p)", real, self);
      cfx_isRunning_logged++;
    }
    return YES;
  }
  return real;
}

static BOOL cfx_session_isInterrupted_hook(id self, SEL _cmd) {
  typedef BOOL (*Fn)(id, SEL);
  BOOL real = ((Fn)cfx_orig_isInterrupted)(self, _cmd);
  if (cfx_session_is_for_vcam(self) && real) {
    if (cfx_isInterrupted_logged < 3) {
      cfxlog(@"[isInterrupted] real=%d -> forcing NO (session=%p)", real, self);
      cfx_isInterrupted_logged++;
    }
    return NO;
  }
  return real;
}

void cfx_install_session_state_lies(void) {
  Class cls = NSClassFromString(@"AVCaptureSession");
  if (!cls) return;
  Method r = class_getInstanceMethod(cls, @selector(isRunning));
  Method i = class_getInstanceMethod(cls, @selector(isInterrupted));
  if (r) {
    cfx_orig_isRunning = method_setImplementation(r, (IMP)cfx_session_isRunning_hook);
    cfxlog(@"installed isRunning lie");
  }
  if (i) {
    cfx_orig_isInterrupted = method_setImplementation(i, (IMP)cfx_session_isInterrupted_hook);
    cfxlog(@"installed isInterrupted lie");
  }
}
