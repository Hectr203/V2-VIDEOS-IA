#include <ptrauth.h>

#include "VCamHooks.h"
#include "VCamImage.h"

// MARK: - BWFigCaptureSession graph callback observation
//
// AVCaptureSession.startRunning → cameracaptured graph build → start → these
// delegate callbacks fire on BWFigCaptureSession. If start fails (error != 0),
// the daemon reports failure back over XPC and client.isRunning stays NO.
// Hook these to see exactly where in the graph startup the failure occurs.

static IMP vcc_sess_didFinishStarting_orig = NULL;
static IMP vcc_sess_didStartSourceNode_orig = NULL;
static IMP vcc_sess_didPrepare_orig = NULL;

typedef void (*VccSessDidFinishStartingFn)(id self, SEL _cmd, id graph, int error);
typedef void (*VccSessDidStartSourceFn)(id self, SEL _cmd, id graph, id node, int error);
typedef void (*VccSessDidPrepareFn)(id self, SEL _cmd, id graph);

static void vcc_sess_didFinishStarting_hook(id self,
                                            SEL _cmd,
                                            id graph,
                                            int error) {
  vcc_log(@"  [Sess graph:didFinishStartingWithError:] self=%p graph=%p err=%d",
          self, graph, error);
  VccSessDidFinishStartingFn orig =
      (VccSessDidFinishStartingFn)vcc_sess_didFinishStarting_orig;
  orig(self, _cmd, graph, error);
}

static void vcc_sess_didStartSourceNode_hook(id self,
                                             SEL _cmd,
                                             id graph,
                                             id node,
                                             int error) {
  vcc_log(@"  [Sess graph:didStartSourceNode:error:] self=%p graph=%p node=%@ err=%d",
          self, graph, node, error);
  VccSessDidStartSourceFn orig =
      (VccSessDidStartSourceFn)vcc_sess_didStartSourceNode_orig;
  orig(self, _cmd, graph, node, error);
}

static void vcc_sess_didPrepare_hook(id self, SEL _cmd, id graph) {
  vcc_log(@"  [Sess graphDidPrepareNodes:] self=%p graph=%p", self, graph);
  VccSessDidPrepareFn orig =
      (VccSessDidPrepareFn)vcc_sess_didPrepare_orig;
  orig(self, _cmd, graph);
}

void vcc_install_session_graph_observation(void) {
  Class cls = NSClassFromString(@"BWFigCaptureSession");
  if (!cls) {
    vcc_log(@"  session-graph obs: class missing");
    return;
  }
  vcc_swizzle_method(cls,
                      @selector(graph:didFinishStartingWithError:),
                      (IMP)vcc_sess_didFinishStarting_hook,
                      &vcc_sess_didFinishStarting_orig);
  vcc_swizzle_method(cls,
                      @selector(graph:didStartSourceNode:error:),
                      (IMP)vcc_sess_didStartSourceNode_hook,
                      &vcc_sess_didStartSourceNode_orig);
  vcc_swizzle_method(cls,
                      @selector(graphDidPrepareNodes:),
                      (IMP)vcc_sess_didPrepare_hook,
                      &vcc_sess_didPrepare_orig);
}

// MARK: - BWFigCaptureSession init capture + pipelines extraction
//
// To splice our manual sink into a real session, we need a handle to its
// FigCaptureSessionPipelines instance. Hook the session's init and, post-orig,
// reach into the _pipelines ivar via KVC. Store globally so the next-stage
// injector has a live reference.

static IMP vcc_sess_initWithFigSess_orig = NULL;
typedef id (*VccSessInitWithFigSessFn)(id self, SEL _cmd, void *figSess);

static id vcc_captured_bw_session = nil;       // strong ref to the BWFigCaptureSession
static id vcc_captured_pipelines = nil;        // its _pipelines ivar value

__attribute__((ns_returns_retained))
static id vcc_sess_initWithFigSess_hook(id self, SEL _cmd, void *figSess) {
  VccSessInitWithFigSessFn orig =
      (VccSessInitWithFigSessFn)vcc_sess_initWithFigSess_orig;
  id ret = orig(self, _cmd, figSess);
  if (ret) {
    vcc_captured_bw_session = ret;
    @try {
      vcc_captured_pipelines = [ret valueForKey:@"pipelines"];
    } @catch (NSException *e) {
      @try {
        vcc_captured_pipelines = [ret valueForKey:@"_pipelines"];
      } @catch (NSException *e2) {
        vcc_captured_pipelines = nil;
      }
    }
    vcc_log(@"  [BWFigCaptureSession init] -> self=%p figSess=%p _pipelines=%p (class=%@)",
            ret, figSess, vcc_captured_pipelines,
            NSStringFromClass([vcc_captured_pipelines class]));
  }
  return ret;
}

void vcc_install_session_init_capture(void) {
  Class cls = NSClassFromString(@"BWFigCaptureSession");
  if (!cls) {
    vcc_log(@"  session-init capture: class missing");
    return;
  }
  vcc_swizzle_method(cls,
                      @selector(initWithFigCaptureSession:),
                      (IMP)vcc_sess_initWithFigSess_hook,
                      &vcc_sess_initWithFigSess_orig);
}

// MARK: - graph-build error suppressors
//
// captureSession_buildGraphWithConfiguration's per-source iteration bails
// to OSStatus -12783 along three known paths on our synth source:
//
//   (1) -[FigCaptureCameraSourcePipeline requiresMasterClock] returns YES,
//       and the post-iteration check (OR of all pipelines' returns) bails
//       on a virtual source that has no real ISP/HW clock.
//   (2) _cs_addObjectToStreamsAttributes returns -12783 when an inherited
//       ivar slot is NULL (called from _FigVideoCaptureSourcesActivate-
//       AndCreateDevices during session activation).
//   (3) -[BWFigVideoCaptureStream initWithCaptureStream:…] sets *errOut
//       = -12783 in its validation-failure path.
//
// (1) is neutralized by rewriting the function's prologue to `mov w0, #0; ret`.
// The function's address is resolved from CMCapture's LC_SYMTAB by name —
// no hardcoded VMA.
//
// (2)+(3) are neutralized by scanning CMCapture's __text for the specific
// MOVN encodings the compiler used to prepare -12783 in w20 / w8, and
// rewriting each to `MOVZ w?, #0`. -12783 is a capture-specific OSStatus
// emitted only by the daemon; over-application is benign because the
// daemon's only consumer in the VM is our synth.

void vcc_install_csp_requires_master_clock_hook(void) {
  vcc_image_t img;
  if (vcc_image_resolve(&img, "FigCaptureSourceServerStart") != 0) {
    vcc_log(@"  graph-build patches: image resolve failed");
    return;
  }

  // (1) Resolve -[FigCaptureCameraSourcePipeline requiresMasterClock] via
  // LC_SYMTAB. The function is called via direct C dispatch (not in the
  // objc method table on observed builds, so swizzling won't work), so
  // we rewrite its prologue in place. The PAC-signed address from the
  // symtab is stripped before the write.
  static const char *const kReqMCSyms[] = {
      "_-[FigCaptureCameraSourcePipeline requiresMasterClock]",
      "-[FigCaptureCameraSourcePipeline requiresMasterClock]",
      NULL,
  };
  uintptr_t reqMC = 0;
  for (unsigned i = 0; kReqMCSyms[i]; i++) {
    reqMC = vcc_lookup_lc_symtab(&img, kReqMCSyms[i]);
    if (reqMC) {
      vcc_log(@"  requiresMasterClock @ 0x%lx (sym=%s)",
              (unsigned long)reqMC, kReqMCSyms[i]);
      break;
    }
  }
  if (reqMC) {
    uintptr_t target = (uintptr_t)ptrauth_strip(
        (void *)reqMC, ptrauth_key_function_pointer);
    uint32_t insn0 = ((const uint32_t *)target)[0];
    uint32_t insn1 = ((const uint32_t *)target)[1];
    // Sanity anchor: the second prologue insn should be pacibsp on every
    // arm64e build that signs return addresses. Refuse the patch if it
    // isn't — we'd rather skip than rewrite an unrelated function.
    if (insn1 != 0xD503237Fu) {
      vcc_log(@"  requiresMasterClock @ 0x%lx: insn1=0x%08x != pacibsp; skip",
              (unsigned long)target, insn1);
    } else {
      int ok1 = vcc_patch_word(target,     insn0, 0x52800000u);  // mov w0, #0
      int ok2 = vcc_patch_word(target + 4, insn1, 0xd65f03c0u);  // ret
      vcc_log(@"  requiresMasterClock prologue patch @ 0x%lx: %d/%d",
              (unsigned long)target, ok1, ok2);
    }
  } else {
    vcc_log(@"  requiresMasterClock symbol not in LC_SYMTAB; patch skipped");
  }

  // (2) `mov w20, #-12783` (MOVN encoding 0x12863dd4) -> `mov w20, #0`.
  vcc_scan_and_patch(&img, 0x12863dd4u, 0x52800014u,
                     "mov w20, #-12783 -> #0");
  // (3) `mov w8, #-12783` (MOVN encoding 0x12863dc8) -> `mov w8, #0`.
  vcc_scan_and_patch(&img, 0x12863dc8u, 0x52800008u,
                     "mov w8, #-12783 -> #0");
}
