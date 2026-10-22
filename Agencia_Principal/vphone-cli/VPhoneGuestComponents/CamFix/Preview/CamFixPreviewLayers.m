// AVCaptureVideoPreviewLayer.contents pump and the layer discovery that
// feeds it.

#import "CamFixPrivate.h"

// MARK: - AVCaptureVideoPreviewLayer.contents pump
//
// AVCaptureVideoPreviewLayer is a CALayer subclass that normally displays
// the camera's preview via internal IOSurface plumbing fed by the daemon.
// For our virtual camera, no daemon-side preview pipeline is built, so the
// layer stays black.
//
// Workaround: capture each AVCaptureVideoPreviewLayer instance bound to
// our virtual camera, and pump CGImage frames into its `contents` property
// at 30 Hz from a background timer. CALayer rendering picks the image up
// without needing the underlying AVF preview infrastructure.

// Weak. Written from the layer hooks (any thread) and the main-queue scan,
// read from the preview queue and the graph's render thread, so every
// access holds the lock.
static NSHashTable *cfx_preview_layers = nil;
static pthread_mutex_t cfx_preview_layers_lock = PTHREAD_MUTEX_INITIALIZER;
static dispatch_source_t cfx_preview_timer = NULL;
static IMP cfx_orig_pv_initWithSession = NULL;
static IMP cfx_orig_pv_initWithSessionMakeConnection = NULL;

// Adds the layers and returns how many were new.
static NSUInteger cfx_preview_add_layers(NSArray *layers) {
  pthread_mutex_lock(&cfx_preview_layers_lock);
  if (!cfx_preview_layers) cfx_preview_layers = [NSHashTable weakObjectsHashTable];
  NSUInteger before = cfx_preview_layers.count;
  for (id layer in layers) [cfx_preview_layers addObject:layer];
  NSUInteger added = cfx_preview_layers.count - before;
  pthread_mutex_unlock(&cfx_preview_layers_lock);
  return added;
}

static NSArray *cfx_preview_layers_snapshot(void) {
  pthread_mutex_lock(&cfx_preview_layers_lock);
  NSArray *layers = cfx_preview_layers.allObjects ?: @[];
  pthread_mutex_unlock(&cfx_preview_layers_lock);
  return layers;
}

BOOL cfx_preview_has_layers(void) {
  pthread_mutex_lock(&cfx_preview_layers_lock);
  BOOL any = cfx_preview_layers.count > 0;
  pthread_mutex_unlock(&cfx_preview_layers_lock);
  return any;
}

static void cfx_pump_preview_once(void) {
  NSArray *layers = cfx_preview_layers_snapshot();
  if (layers.count == 0) {
    // Nothing to show: drop the graph sample the tap may still hold.
    cfx_tap_clear();
    return;
  }
  CGImageRef img = NULL;
  // Preferred: the sample the capture graph just delivered.
  CMSampleBufferRef sb = cfx_tap_fetch_fresh();
  if (sb) {
    CVPixelBufferRef pb = CMSampleBufferGetImageBuffer(sb);
    if (pb) img = vcc_cgimage_from_pixel_buffer(pb);
    CFRelease(sb);
  }
  // Bootstrap fallback: no graph yet, straight from the shm frame.
  if (!img) img = cfx_build_cgimage_from_shm();
  if (!img) return;
  dispatch_async(dispatch_get_main_queue(), ^{
    for (CALayer *layer in layers) {
      layer.contents = (__bridge id)img;
      layer.contentsGravity = kCAGravityResizeAspectFill;
    }
    CGImageRelease(img);
  });
}

// Callers run on any thread; the timer is created once.
void cfx_preview_start_timer(void) {
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    dispatch_queue_t q = dispatch_queue_create("com.vphone.camfix.preview", DISPATCH_QUEUE_SERIAL);
    cfx_preview_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, q);
    dispatch_source_set_timer(
        cfx_preview_timer,
        dispatch_time(DISPATCH_TIME_NOW, 0),
        33333333ull,
        2000000ull);
    dispatch_source_set_event_handler(cfx_preview_timer, ^{
      @autoreleasepool {
        cfx_pump_preview_once();
        cfx_deliver_video_frames_once();
      }
    });
    dispatch_resume(cfx_preview_timer);
    cfxlog(@"preview pump armed (30 Hz)");
  });
}

static void cfx_adopt_preview_layer(id layer) {
  cfx_preview_add_layers(@[ layer ]);
  cfx_preview_start_timer();
}

// MARK: - preview layer hooks

__attribute__((ns_returns_retained))
static id cfx_pv_initWithSession_hook(id self, SEL _cmd, AVCaptureSession *session) {
  typedef id (*Fn)(id, SEL, AVCaptureSession *);
  id ret = ((Fn)cfx_orig_pv_initWithSession)(self, _cmd, session);
  BOOL forVcam = (session != nil) && cfx_session_is_for_vcam(session);
  cfxlog(@"[PVLayer initWithSession:%p] ret=%p forVcam=%d cls=%@",
         session,
         ret,
         forVcam,
         NSStringFromClass([ret class]));
  if (ret && forVcam) cfx_adopt_preview_layer(ret);
  return ret;
}

__attribute__((ns_returns_retained))
static id cfx_pv_initWithSessionMakeConnection_hook(
    id self,
    SEL _cmd,
    AVCaptureSession *session,
    BOOL makeConnection) {
  typedef id (*Fn)(id, SEL, AVCaptureSession *, BOOL);
  id ret = ((Fn)cfx_orig_pv_initWithSessionMakeConnection)(
      self,
      _cmd,
      session,
      makeConnection);
  BOOL forVcam = (session != nil) && cfx_session_is_for_vcam(session);
  cfxlog(@"[PVLayer _initWithSession:%p makeConnection:%d] ret=%p forVcam=%d cls=%@",
         session,
         makeConnection,
         ret,
         forVcam,
         NSStringFromClass([ret class]));
  if (ret && forVcam) cfx_adopt_preview_layer(ret);
  return ret;
}

static IMP cfx_orig_pv_setSession = NULL;
static void cfx_pv_setSession_hook(id self, SEL _cmd, AVCaptureSession *session) {
  typedef void (*Fn)(id, SEL, AVCaptureSession *);
  ((Fn)cfx_orig_pv_setSession)(self, _cmd, session);
  BOOL forVcam = (session != nil) && cfx_session_is_for_vcam(session);
  cfxlog(@"[PVLayer setSession:%p] self=%p forVcam=%d cls=%@",
         session,
         self,
         forVcam,
         NSStringFromClass([self class]));
  if (session && forVcam) cfx_adopt_preview_layer(self);
}

void cfx_install_preview_layer_hooks(void) {
  Class cls = NSClassFromString(@"AVCaptureVideoPreviewLayer");
  if (!cls) { cfxlog(@"AVCaptureVideoPreviewLayer missing"); return; }
  SEL s1 = @selector(initWithSession:);
  SEL s2 = NSSelectorFromString(@"_initWithSession:makeConnection:");
  SEL s3 = @selector(setSession:);
  Method m1 = class_getInstanceMethod(cls, s1);
  Method m2 = class_getInstanceMethod(cls, s2);
  Method m3 = class_getInstanceMethod(cls, s3);
  if (m1) {
    cfx_orig_pv_initWithSession =
        method_setImplementation(m1, (IMP)cfx_pv_initWithSession_hook);
  }
  if (m2) {
    cfx_orig_pv_initWithSessionMakeConnection =
        method_setImplementation(m2, (IMP)cfx_pv_initWithSessionMakeConnection_hook);
  }
  if (m3) {
    cfx_orig_pv_setSession =
        method_setImplementation(m3, (IMP)cfx_pv_setSession_hook);
  }
  cfxlog(@"installed PVLayer hooks (init=%p initMC=%p setSession=%p)",
         cfx_orig_pv_initWithSession,
         cfx_orig_pv_initWithSessionMakeConnection,
         cfx_orig_pv_setSession);
}

// MARK: - preview layer scan
//
// Fallback: scan UIApplication's windows for any AVCaptureVideoPreviewLayer
// (or subclass) and adopt them. Covers a private layer class that never
// goes through the hooks above. Runs once a second once a vcam session runs;
// cheap if no windows match.

static void cfx_walk_layers(CALayer *layer, NSMutableArray *out) {
  if (!layer) return;
  Class avcvpl = NSClassFromString(@"AVCaptureVideoPreviewLayer");
  if (avcvpl && [layer isKindOfClass:avcvpl]) {
    [out addObject:layer];
  }
  for (CALayer *sub in layer.sublayers) {
    cfx_walk_layers(sub, out);
  }
}

static void cfx_scan_preview_layers(void) {
  Class UIApp = NSClassFromString(@"UIApplication");
  if (!UIApp) return;
  id app = [UIApp performSelector:@selector(sharedApplication)];
  if (!app) return;
  NSArray *windows = nil;
  @try {
    // iOS 13+: connectedScenes → UIWindowScene → windows
    NSSet *scenes = [app valueForKey:@"connectedScenes"];
    NSMutableArray *all = [NSMutableArray array];
    for (id scene in scenes) {
      @try {
        NSArray *w = [scene valueForKey:@"windows"];
        if (w) [all addObjectsFromArray:w];
      } @catch (NSException *e) {}
    }
    if (all.count > 0) windows = all;
  } @catch (NSException *e) {}
  if (!windows.count) {
    @try { windows = [app valueForKey:@"windows"]; } @catch (NSException *e) {}
  }
  if (!windows.count) return;

  NSMutableArray *found = [NSMutableArray array];
  for (id w in windows) {
    @try {
      CALayer *root = [w valueForKey:@"layer"];
      cfx_walk_layers(root, found);
    } @catch (NSException *e) {}
  }
  if (found.count == 0) return;
  NSUInteger added = cfx_preview_add_layers(found);
  if (added > 0) {
    cfxlog(@"[scan] adopted %lu preview layer(s)", (unsigned long)added);
    cfx_preview_start_timer();
  }
}

static dispatch_source_t cfx_scan_timer = NULL;
// Started by the first running vcam session (Session/CamFixSessionGuards.m).
// Callers run on any thread; the timer is created once.
void cfx_start_scan_timer(void) {
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    cfx_scan_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                                            dispatch_get_main_queue());
    dispatch_source_set_timer(cfx_scan_timer,
                              dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                              1000000000ull,
                              100000000ull);
    dispatch_source_set_event_handler(cfx_scan_timer, ^{
      @autoreleasepool { cfx_scan_preview_layers(); }
    });
    dispatch_resume(cfx_scan_timer);
    cfxlog(@"scan timer armed (1 Hz)");
  });
}
