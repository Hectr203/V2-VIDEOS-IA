#include "VCamFrames.h"
#include "VCamHooks.h"

// MARK: - frame-sender endpoint observation
//
// AVF capture clients (Camera.app, AVCaptureSession-using apps) tell the
// daemon "I want frames from camera X" by publishing a FrameSenderEndpoint
// — XPC handler `_captureSourceServer_handlePublishFrameSenderEndpointMessage`
// in CMCapture forwards each publish into the daemon-side class
// `CMCaptureFrameSenderEndpointsServerSideSingleton` via the
// `+addEndpoint:endpointUniqueID:endpointType:endpointPID:endpointProxyPID:
//   endpointAuditToken:endpointProxyAuditToken:endpointCameraUniqueID:`
// class method. Each endpoint carries the requesting client's audit token
// and the camera unique-ID they want frames for. Our synth's unique-ID is
// "vphone:vcam:0", so any endpoint whose cameraUniqueID matches that string
// is a client expecting frames from us.
//
// We swizzle the class method below to log every registration. Once we
// see Camera.app (or rpcserver_ios) publishing an endpoint for our synth,
// we know the next sub-stage is to build a `-[CMCaptureFrameSenderService
// sendFrame:]` call path that pushes CMSampleBuffers built from our shm
// `vcc_latest_frame` into each registered endpoint.
//
// This hook is observation-only; it does not deliver frames yet.

static IMP vcc_add_endpoint_orig_imp = NULL;

typedef BOOL (*VccAddEndpointFn)(id,
                                 SEL,
                                 id /*endpoint*/,
                                 id /*endpointUniqueID*/,
                                 int /*endpointType*/,
                                 int /*endpointPID*/,
                                 int /*endpointProxyPID*/,
                                 audit_token_t * /*auditToken*/,
                                 audit_token_t * /*proxyAuditToken*/,
                                 id /*endpointCameraUniqueID*/);

static BOOL vcc_add_endpoint_hook(id self,
                                  SEL _cmd,
                                  id endpoint,
                                  id endpointUniqueID,
                                  int endpointType,
                                  int endpointPID,
                                  int endpointProxyPID,
                                  audit_token_t *auditToken,
                                  audit_token_t *proxyAuditToken,
                                  id endpointCameraUniqueID) {
  vcc_log(@"  +addEndpoint cameraID=%@ pid=%d type=%d endpointUniqueID=%@",
          endpointCameraUniqueID, endpointPID, endpointType, endpointUniqueID);
  if (!vcc_add_endpoint_orig_imp) return NO;
  VccAddEndpointFn orig = (VccAddEndpointFn)vcc_add_endpoint_orig_imp;
  BOOL ok = orig(self, _cmd, endpoint, endpointUniqueID, endpointType,
                  endpointPID, endpointProxyPID, auditToken,
                  proxyAuditToken, endpointCameraUniqueID);
  vcc_log(@"  +addEndpoint orig returned %d", ok);
  return ok;
}

void vcc_install_endpoint_hook(void) {
  Class cls = NSClassFromString(
      @"CMCaptureFrameSenderEndpointsServerSideSingleton");
  if (!cls) {
    vcc_log(@"  endpoint hook: class missing");
    return;
  }
  SEL sel = NSSelectorFromString(
      @"addEndpoint:endpointUniqueID:endpointType:endpointPID:"
      @"endpointProxyPID:endpointAuditToken:endpointProxyAuditToken:"
      @"endpointCameraUniqueID:");
  Method m = class_getClassMethod(cls, sel);
  if (!m) {
    vcc_log(@"  endpoint hook: class_getClassMethod returned NULL");
    return;
  }
  vcc_add_endpoint_orig_imp = method_setImplementation(m, (IMP)vcc_add_endpoint_hook);
  vcc_log(@"  endpoint hook installed (orig=%p)",
          vcc_add_endpoint_orig_imp);
}

// MARK: - sink-node diagnostic dump
//
// Enumerate the BWImageQueueSinkNode + BWRemoteQueueSinkNode method tables
// at runtime so we can identify the actual init / setup / render selectors
// the session pipeline invokes. The static class-dump on the DSC binary
// returns garbled selptr references — at runtime the selector table is
// resolved, so this dump is reliable. Result lands in the vcamcaptured.log
// file; we use it to pick the right hook target for stage G.

static void vcc_dump_class(const char *name) {
  Class cls = NSClassFromString(@(name));
  if (!cls) {
    vcc_log(@"  class %s NOT FOUND", name);
    return;
  }
  Class super = class_getSuperclass(cls);
  vcc_log(@"  class %s @ %p (super=%s)", name, cls,
          super ? class_getName(super) : "<root>");

  unsigned int count = 0;
  Method *list = class_copyMethodList(cls, &count);
  vcc_log(@"  -- instance methods (%u) --", count);
  for (unsigned i = 0; i < count; i++) {
    Method m = list[i];
    SEL s = method_getName(m);
    IMP imp = method_getImplementation(m);
    const char *types = method_getTypeEncoding(m);
    vcc_log(@"    -[%s %@]  imp=%p types=%s", name,
            NSStringFromSelector(s), (void *)imp,
            types ? types : "?");
  }
  free(list);

  Class meta = object_getClass((id)cls);
  count = 0;
  Method *clist = class_copyMethodList(meta, &count);
  vcc_log(@"  -- class methods (%u) --", count);
  for (unsigned i = 0; i < count; i++) {
    Method m = clist[i];
    SEL s = method_getName(m);
    IMP imp = method_getImplementation(m);
    vcc_log(@"    +[%s %@]  imp=%p", name,
            NSStringFromSelector(s), (void *)imp);
  }
  free(clist);
}

void vcc_dump_sink_node_methods(void) {
  vcc_log(@"---- sink-node method dump ----");
  vcc_dump_class("BWSinkNode");
  vcc_dump_class("BWImageQueueSinkNode");
  vcc_dump_class("BWRemoteQueueSinkNode");
  vcc_dump_class("BWFigCaptureSession");
  vcc_dump_class("BWFigCaptureDeviceVendor");
  vcc_dump_class("FigCaptureSourceBacking");
  vcc_dump_class("FigCaptureVideoSourceBacking");
  vcc_dump_class("FigCameraViewfinderStream");
  vcc_dump_class("FigCameraViewfinderSessionLocal");
  vcc_dump_class("FigCameraViewfinderLocal");
  vcc_dump_class("BWPreviewTimeMachineSinkNode");
  // Photo-path classes for capturePhoto debugging
  vcc_dump_class("BWStillImageCaptureCoordinator");
  vcc_dump_class("BWStillImageSampleBufferSinkNode");
  vcc_dump_class("BWStillImageProcessorController");
  vcc_dump_class("BWFigCaptureStillImageRequest");
  vcc_dump_class("FigCaptureCameraSourcePipeline");
  vcc_dump_class("FigCaptureSourcePipeline");
  vcc_log(@"---- end sink-node method dump ----");
}

// MARK: - sink observation hooks
//
// Stage G observation pass: swizzle the two sink classes' init + render
// methods. Goals:
//   1) Confirm whether sinks are instantiated when an AVF client opens our
//      synth source (i.e. is the pipeline starved at the SOURCE end or at the
//      configuration end?).
//   2) See whether ANY renderSampleBuffer:forInput: calls fire — if they do,
//      we know the pipeline runs and we just need to substitute the
//      sample-buffer contents.

// Video sink nodes (BWImageQueueSinkNode / BWRemoteQueueSinkNode) created
// for any client session. Weak refs: the capture graph owns each node, so a
// node drops out of the table when its session tears down, and the drive
// loop never feeds a dead graph or keeps one alive. The snapshot holds
// strong refs for the length of one drive tick. The viewfinder queue drives
// them (vcc_drive_sinks_once) while the init hooks add from graph-build
// threads, so every access holds the lock.
static NSHashTable *vcc_driven_sinks = nil;
static pthread_mutex_t vcc_driven_sinks_lock = PTHREAD_MUTEX_INITIALIZER;

static void vcc_track_driven_sink(id sink) {
  if (!sink) return;
  pthread_mutex_lock(&vcc_driven_sinks_lock);
  if (!vcc_driven_sinks) vcc_driven_sinks = [NSHashTable weakObjectsHashTable];
  [vcc_driven_sinks addObject:sink];
  pthread_mutex_unlock(&vcc_driven_sinks_lock);
  vcc_frame_drive_wake();
}

NSArray *vcc_driven_sinks_snapshot(void) {
  pthread_mutex_lock(&vcc_driven_sinks_lock);
  NSArray *snapshot = vcc_driven_sinks.allObjects ?: @[];
  pthread_mutex_unlock(&vcc_driven_sinks_lock);
  return snapshot;
}

static unsigned long vcc_render_call_count = 0;
static unsigned long vcc_iqsn_init_count = 0;
static unsigned long vcc_rqsn_init_count = 0;

static IMP vcc_iqsn_init_orig = NULL;
static IMP vcc_rqsn_init_orig = NULL;
static IMP vcc_iqsn_render_orig = NULL;
static IMP vcc_rqsn_render_orig = NULL;

typedef id (*VccIqsnInitFn)(
    id self,
    SEL _cmd,
    BOOL hfrSupport,
    BOOL ispJitterCompensationEnabled,
    audit_token_t auditToken,
    id sinkID);

typedef id (*VccRqsnInitFn)(
    id self,
    SEL _cmd,
    uint32_t mediaType,
    audit_token_t auditToken,
    id sinkID,
    id cameraInfoByPortType);

typedef void (*VccRenderFn)(
    id self,
    SEL _cmd,
    CMSampleBufferRef cmsb,
    id input);

static id vcc_iqsn_init_hook(
    id self,
    SEL _cmd,
    BOOL hfrSupport,
    BOOL ispJitterCompensationEnabled,
    audit_token_t auditToken,
    id sinkID) {
  VccIqsnInitFn orig = (VccIqsnInitFn)vcc_iqsn_init_orig;
  id ret = orig(self, _cmd, hfrSupport, ispJitterCompensationEnabled,
                auditToken, sinkID);
  vcc_iqsn_init_count++;
  vcc_log(@"  [IQSN init] -> %p sinkID=%@ count=%lu",
          ret, sinkID, vcc_iqsn_init_count);
  vcc_track_driven_sink(ret);
  return ret;
}

static id vcc_rqsn_init_hook(
    id self,
    SEL _cmd,
    uint32_t mediaType,
    audit_token_t auditToken,
    id sinkID,
    id cameraInfoByPortType) {
  VccRqsnInitFn orig = (VccRqsnInitFn)vcc_rqsn_init_orig;
  id ret = orig(self, _cmd, mediaType, auditToken, sinkID,
                cameraInfoByPortType);
  vcc_rqsn_init_count++;
  vcc_log(@"  [RQSN init] -> %p mediaType=0x%x sinkID=%@ count=%lu",
          ret, mediaType, sinkID, vcc_rqsn_init_count);
  vcc_track_driven_sink(ret);
  return ret;
}

static void vcc_iqsn_render_hook(
    id self,
    SEL _cmd,
    CMSampleBufferRef cmsb,
    id input) {
  vcc_render_call_count++;
  if (vcc_render_call_count <= 5 || (vcc_render_call_count & 63) == 1) {
    vcc_log(@"  [IQSN render] self=%p cmsb=%p input=%p inputCls=%@ #%lu",
            self, cmsb, input, NSStringFromClass([input class]),
            vcc_render_call_count);
  }
  VccRenderFn orig = (VccRenderFn)vcc_iqsn_render_orig;
  orig(self, _cmd, cmsb, input);
}

static void vcc_rqsn_render_hook(
    id self,
    SEL _cmd,
    CMSampleBufferRef cmsb,
    id input) {
  vcc_render_call_count++;
  if (vcc_render_call_count <= 5 || (vcc_render_call_count & 63) == 1) {
    vcc_log(@"  [RQSN render] self=%p cmsb=%p input=%p inputCls=%@ #%lu",
            self, cmsb, input, NSStringFromClass([input class]),
            vcc_render_call_count);
  }
  VccRenderFn orig = (VccRenderFn)vcc_rqsn_render_orig;
  orig(self, _cmd, cmsb, input);
}

void vcc_install_sink_observation(void) {
  Class iqsn = NSClassFromString(@"BWImageQueueSinkNode");
  Class rqsn = NSClassFromString(@"BWRemoteQueueSinkNode");
  if (!iqsn || !rqsn) {
    vcc_log(@"  sink obs: classes missing iqsn=%p rqsn=%p", iqsn, rqsn);
    return;
  }

  SEL iqsnInit = NSSelectorFromString(
      @"initWithHFRSupport:ispJitterCompensationEnabled:"
      @"clientAuditToken:sinkID:");
  SEL rqsnInit = NSSelectorFromString(
      @"initWithMediaType:clientAuditToken:sinkID:cameraInfoByPortType:");
  SEL renderSel = @selector(renderSampleBuffer:forInput:);

  vcc_swizzle_method(iqsn, iqsnInit, (IMP)vcc_iqsn_init_hook,
                      &vcc_iqsn_init_orig);
  vcc_swizzle_method(rqsn, rqsnInit, (IMP)vcc_rqsn_init_hook,
                      &vcc_rqsn_init_orig);
  vcc_swizzle_method(iqsn, renderSel, (IMP)vcc_iqsn_render_hook,
                      &vcc_iqsn_render_orig);
  vcc_swizzle_method(rqsn, renderSel, (IMP)vcc_rqsn_render_hook,
                      &vcc_rqsn_render_orig);
}
