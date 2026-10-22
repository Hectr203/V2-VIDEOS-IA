#include "VCamHooks.h"

// MARK: - BWStillImageSampleBufferSinkNode observation + injection
//
// AVCapturePhotoOutput attaches a sampleBufferAvailableHandler block to the
// still-image sink node; the upstream graph normally drives the node by
// calling -renderSampleBuffer:forInput:, which routes the buffer through
// the node's internal logic and ultimately invokes the handler. Our synth
// has no upstream graph that produces frames, so the handler never fires.
//
// First pass: observe. Hook -setSampleBufferAvailableHandler: and
// -initWithInputMediaType:sinkID: to capture the node + the handler
// block per session, so we can later push a CMSampleBuffer ourselves.

static NSMutableArray *vcc_still_sinks = nil;   // strong refs to nodes
static IMP vcc_still_set_handler_orig = NULL;
static IMP vcc_still_init_orig        = NULL;
static IMP vcc_still_render_orig      = NULL;

// mediaType is a FourCC ('vide'), not an object: typed as id, ARC retains it
// and cameracaptured crashes at 0x76696465 on iOS 18 (#541).
typedef id  (*VccStillInitFn)(id self, SEL _cmd, uint32_t mediaType, id sinkID);
typedef void (*VccStillSetHandlerFn)(id self, SEL _cmd, id handler);
typedef void (*VccStillRenderFn)(id self, SEL _cmd, CMSampleBufferRef sb, id input);

static id vcc_still_init_hook(id self, SEL _cmd, uint32_t mediaType, id sinkID) {
  VccStillInitFn orig = (VccStillInitFn)vcc_still_init_orig;
  id ret = orig(self, _cmd, mediaType, sinkID);
  vcc_log(@"  [StillSink init] self=%p mediaType=0x%08x sinkID=%@",
          ret, mediaType, sinkID);
  if (ret) {
    if (!vcc_still_sinks) vcc_still_sinks = [NSMutableArray new];
    [vcc_still_sinks addObject:ret];
  }
  return ret;
}

static void vcc_still_set_handler_hook(id self, SEL _cmd, id handler) {
  vcc_log(@"  [StillSink setSampleBufferAvailableHandler:] self=%p handler=%p",
          self, handler);
  VccStillSetHandlerFn orig = (VccStillSetHandlerFn)vcc_still_set_handler_orig;
  orig(self, _cmd, handler);
}

static void vcc_still_render_hook(id self,
                                  SEL _cmd,
                                  CMSampleBufferRef sb,
                                  id input) {
  vcc_log(@"  [StillSink renderSampleBuffer:forInput:] self=%p sb=%p input=%@",
          self, sb, input);
  VccStillRenderFn orig = (VccStillRenderFn)vcc_still_render_orig;
  orig(self, _cmd, sb, input);
}

void vcc_install_still_sink_observation(void) {
  Class cls = NSClassFromString(@"BWStillImageSampleBufferSinkNode");
  if (!cls) {
    vcc_log(@"  still-sink obs: class missing");
    return;
  }
  SEL initSel = NSSelectorFromString(@"initWithInputMediaType:sinkID:");
  SEL setHSel = @selector(setSampleBufferAvailableHandler:);
  SEL renderSel = @selector(renderSampleBuffer:forInput:);
  vcc_swizzle_method(cls, initSel,
                      (IMP)vcc_still_init_hook, &vcc_still_init_orig);
  vcc_swizzle_method(cls, setHSel,
                      (IMP)vcc_still_set_handler_hook,
                      &vcc_still_set_handler_orig);
  vcc_swizzle_method(cls, renderSel,
                      (IMP)vcc_still_render_hook, &vcc_still_render_orig);
}

// MARK: - BWFigCaptureSession stillImageCoordinator observation
//
// AVCapturePhotoOutput.capturePhoto → daemon-side BWStillImageCaptureCoordinator
// queues a request and fires these delegate callbacks on BWFigCaptureSession.
// If willBegin… fires but didCapture… doesn't, the photo pipeline received
// the request but couldn't satisfy it (typically because no sample buffer
// arrived for it to wrap into a photo).

static IMP vcc_sess_willBeginPhoto_orig = NULL;
static IMP vcc_sess_willBeginPhotoForSettings_orig = NULL;
static IMP vcc_sess_willPreparePhoto_orig = NULL;
static IMP vcc_sess_willCapturePhoto_orig = NULL;
static IMP vcc_sess_didCapturePhoto_orig = NULL;

typedef void (*VccSessWillBeginPhotoFn)(id self, SEL _cmd, id coord, long settingsID);
typedef void (*VccSessSettingsFn)(id self, SEL _cmd, id coord, id settings);
typedef void (*VccSessWillPrepareFn)(id self, SEL _cmd, id coord, id settings, BOOL clientInitiated);
typedef void (*VccSessWillCaptureFn)(id self, SEL _cmd, id coord, id settings, int err);

static void vcc_sess_willBeginPhoto_hook(id self,
                                         SEL _cmd,
                                         id coord,
                                         long settingsID) {
  vcc_log(@"  [Sess stillImageCoordinator:willBeginCaptureBeforeResolvingSettingsForID:] coord=%p id=%ld",
          coord, settingsID);
  VccSessWillBeginPhotoFn orig =
      (VccSessWillBeginPhotoFn)vcc_sess_willBeginPhoto_orig;
  orig(self, _cmd, coord, settingsID);
}

static void vcc_sess_willBeginPhotoForSettings_hook(id self,
                                                    SEL _cmd,
                                                    id coord,
                                                    id settings) {
  vcc_log(@"  [Sess stillImageCoordinator:willBeginCaptureForSettings:] coord=%p settings=%@",
          coord, settings);
  VccSessSettingsFn orig =
      (VccSessSettingsFn)vcc_sess_willBeginPhotoForSettings_orig;
  orig(self, _cmd, coord, settings);
}

static void vcc_sess_willPreparePhoto_hook(id self,
                                           SEL _cmd,
                                           id coord,
                                           id settings,
                                           BOOL clientInitiated) {
  vcc_log(@"  [Sess stillImageCoordinator:willPrepareStillImageCaptureWithSettings:clientInitiated:] coord=%p settings=%@ ci=%d",
          coord, settings, clientInitiated);
  VccSessWillPrepareFn orig =
      (VccSessWillPrepareFn)vcc_sess_willPreparePhoto_orig;
  orig(self, _cmd, coord, settings, clientInitiated);
}

static void vcc_sess_willCapturePhoto_hook(id self,
                                           SEL _cmd,
                                           id coord,
                                           id settings,
                                           int err) {
  vcc_log(@"  [Sess stillImageCoordinator:willCapturePhotoForSettings:error:] coord=%p settings=%@ err=%d",
          coord, settings, err);
  VccSessWillCaptureFn orig =
      (VccSessWillCaptureFn)vcc_sess_willCapturePhoto_orig;
  orig(self, _cmd, coord, settings, err);
}

static void vcc_sess_didCapturePhoto_hook(id self,
                                          SEL _cmd,
                                          id coord,
                                          id settings) {
  vcc_log(@"  [Sess stillImageCoordinator:didCapturePhotoForSettings:] coord=%p settings=%@",
          coord, settings);
  VccSessSettingsFn orig =
      (VccSessSettingsFn)vcc_sess_didCapturePhoto_orig;
  orig(self, _cmd, coord, settings);
}

void vcc_install_still_coordinator_observation(void) {
  Class cls = NSClassFromString(@"BWFigCaptureSession");
  if (!cls) {
    vcc_log(@"  still-coord obs: BWFigCaptureSession missing");
    return;
  }
  vcc_swizzle_method(cls,
                      @selector(stillImageCoordinator:willBeginCaptureBeforeResolvingSettingsForID:),
                      (IMP)vcc_sess_willBeginPhoto_hook,
                      &vcc_sess_willBeginPhoto_orig);
  vcc_swizzle_method(cls,
                      @selector(stillImageCoordinator:willBeginCaptureForSettings:),
                      (IMP)vcc_sess_willBeginPhotoForSettings_hook,
                      &vcc_sess_willBeginPhotoForSettings_orig);
  vcc_swizzle_method(cls,
                      @selector(stillImageCoordinator:willPrepareStillImageCaptureWithSettings:clientInitiated:),
                      (IMP)vcc_sess_willPreparePhoto_hook,
                      &vcc_sess_willPreparePhoto_orig);
  vcc_swizzle_method(cls,
                      @selector(stillImageCoordinator:willCapturePhotoForSettings:error:),
                      (IMP)vcc_sess_willCapturePhoto_hook,
                      &vcc_sess_willCapturePhoto_orig);
  vcc_swizzle_method(cls,
                      @selector(stillImageCoordinator:didCapturePhotoForSettings:),
                      (IMP)vcc_sess_didCapturePhoto_hook,
                      &vcc_sess_didCapturePhoto_orig);
}

// MARK: - BWStillImageCoordinatorNode existence detector
//
// If our synth session never instantiates BWStillImageCoordinatorNode, the
// capturePhoto request has nowhere to land. Swizzle its known internal
// method (-_enqueueRequestWithSettings:serviceRequestsIfNecessary:) so we
// detect whether the coordinator exists and ever sees a capture request.

static IMP vcc_still_coord_enqueue_orig = NULL;
typedef void (*VccStillCoordEnqueueFn)(id self, SEL _cmd, id settings, BOOL serviceIfNecessary);

static void vcc_still_coord_enqueue_hook(id self,
                                         SEL _cmd,
                                         id settings,
                                         BOOL serviceIfNecessary) {
  vcc_log(@"  [StillCoord enqueueRequest] self=%p settings=%@ service=%d",
          self, settings, serviceIfNecessary);
  VccStillCoordEnqueueFn orig =
      (VccStillCoordEnqueueFn)vcc_still_coord_enqueue_orig;
  orig(self, _cmd, settings, serviceIfNecessary);
}

void vcc_install_still_coord_node_observation(void) {
  Class cls = NSClassFromString(@"BWStillImageCoordinatorNode");
  if (!cls) {
    vcc_log(@"  still-coord-node obs: class missing");
    return;
  }
  vcc_swizzle_method(cls,
                      @selector(_enqueueRequestWithSettings:serviceRequestsIfNecessary:),
                      (IMP)vcc_still_coord_enqueue_hook,
                      &vcc_still_coord_enqueue_orig);
}

// MARK: - FigCaptureStillImageSinkPipeline init detector
//
// Per CMCapture symbols, the still pipeline is constructed via:
//   -[FigCaptureStillImageSinkPipeline initWithConfiguration:captureDevice:
//      sourceOutputsByPortType:captureStatusDelegate:inferenceScheduler:
//      graph:name:]
// Hook this to see if it's called for our synth session, and what its
// arguments look like. If it's never called, the daemon's graph-build code
// decides upstream that no still pipeline is needed (probably based on a
// source attribute). If it's called and returns nil, we can inspect the
// arguments to figure out which is missing.

static IMP vcc_still_pipe_init_orig = NULL;
typedef id (*VccStillPipeInitFn)(id self,
                                 SEL _cmd,
                                 id config,
                                 id device,
                                 id outputsByPortType,
                                 id captureStatusDelegate,
                                 id inferenceScheduler,
                                 id graph,
                                 id name);

__attribute__((ns_returns_retained))
static id vcc_still_pipe_init_hook(id self,
                                   SEL _cmd,
                                   id config,
                                   id device,
                                   id outputsByPortType,
                                   id captureStatusDelegate,
                                   id inferenceScheduler,
                                   id graph,
                                   id name) {
  vcc_log(@"  [StillPipe init] self=%p config=%@ device=%@ outputs.count=%lu name=%@",
          self, config, device,
          (unsigned long)([outputsByPortType respondsToSelector:@selector(count)]
                          ? [outputsByPortType count] : 0),
          name);
  VccStillPipeInitFn orig = (VccStillPipeInitFn)vcc_still_pipe_init_orig;
  id ret = orig(self, _cmd, config, device, outputsByPortType,
                captureStatusDelegate, inferenceScheduler, graph, name);
  vcc_log(@"  [StillPipe init] -> %p", ret);
  return ret;
}

void vcc_install_still_pipeline_observation(void) {
  Class cls = NSClassFromString(@"FigCaptureStillImageSinkPipeline");
  if (!cls) {
    vcc_log(@"  still-pipe obs: class missing");
    return;
  }
  SEL sel = NSSelectorFromString(
      @"initWithConfiguration:captureDevice:sourceOutputsByPortType:"
      @"captureStatusDelegate:inferenceScheduler:graph:name:");
  vcc_swizzle_method(cls, sel, (IMP)vcc_still_pipe_init_hook,
                      &vcc_still_pipe_init_orig);
}

// MARK: - FigCaptureSessionPipelines.addStillImageSinkPipelineSessionStorage
//
// Per CMCapture symbols, this is the daemon-side method that registers a
// still-image sink pipeline with the session. If captureSession_buildGraph-
// WithConfiguration's still-pipeline branch ever runs for our synth source,
// this method gets called. If it's never called for our test, the upstream
// gate (parsed still-image sink configurations array empty?) is what we
// need to address.

static IMP vcc_pipelines_addStill_orig = NULL;
typedef void (*VccPipelinesAddStillFn)(id self, SEL _cmd, id storage);

static void vcc_pipelines_addStill_hook(id self, SEL _cmd, id storage) {
  vcc_log(@"  [Pipelines addStillImageSinkPipelineSessionStorage:] self=%p storage=%@",
          self, storage);
  VccPipelinesAddStillFn orig =
      (VccPipelinesAddStillFn)vcc_pipelines_addStill_orig;
  orig(self, _cmd, storage);
}

void vcc_install_pipelines_addStill_observation(void) {
  Class cls = NSClassFromString(@"FigCaptureSessionPipelines");
  if (!cls) {
    vcc_log(@"  pipelines obs: class missing");
    return;
  }
  vcc_swizzle_method(cls,
                      @selector(addStillImageSinkPipelineSessionStorage:),
                      (IMP)vcc_pipelines_addStill_hook,
                      &vcc_pipelines_addStill_orig);
}
