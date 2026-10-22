// The client-side tail of the capture graph, tapped so the preview can show
// the sample the graph delivered and video delivery knows when to stand
// down.

#import "CamFixPrivate.h"

// MARK: - preview fed from the client's capture graph
//
// A real camera has one path: capture graph -> sample buffer -> preview
// surface. While a vcam preview layer is live, tap the client-side sink node
// that receives the capture graph's sample buffers and feed the preview from
// that sample — the same frame, timestamp, pixel format and camera metadata
// every other consumer sees. The shm reader is the bootstrap fallback for
// the window before the daemon builds the graph (preview-only sessions).

static pthread_mutex_t cfx_tap_lock = PTHREAD_MUTEX_INITIALIZER;
static CMSampleBufferRef cfx_tap_latest = NULL;  // retained, guarded
static CFAbsoluteTime cfx_tap_latest_at = 0;     // guarded
#define CFX_TAP_STALE_SECONDS 0.5

static void cfx_tap_store(CMSampleBufferRef sb) {
  CFRetain(sb);
  pthread_mutex_lock(&cfx_tap_lock);
  CMSampleBufferRef old = cfx_tap_latest;
  cfx_tap_latest = sb;
  cfx_tap_latest_at = CFAbsoluteTimeGetCurrent();
  pthread_mutex_unlock(&cfx_tap_lock);
  if (old) CFRelease(old);
}

// Returns a retained latest sample, or NULL if none is fresh.
CMSampleBufferRef cfx_tap_fetch_fresh(void) {
  CMSampleBufferRef out = NULL;
  pthread_mutex_lock(&cfx_tap_lock);
  if (cfx_tap_latest &&
      CFAbsoluteTimeGetCurrent() - cfx_tap_latest_at < CFX_TAP_STALE_SECONDS) {
    out = (CMSampleBufferRef)CFRetain(cfx_tap_latest);
  }
  pthread_mutex_unlock(&cfx_tap_lock);
  return out;
}

void cfx_tap_clear(void) {
  pthread_mutex_lock(&cfx_tap_lock);
  CMSampleBufferRef old = cfx_tap_latest;
  cfx_tap_latest = NULL;
  pthread_mutex_unlock(&cfx_tap_lock);
  if (old) CFRelease(old);
}

// When the capture graph last delivered a sample to this process. Video
// delivery is the fallback for sessions whose graph never runs; once the
// graph delivers, the data outputs are fed natively and the fallback must
// stop, or delegates would see two interleaved streams.
static _Atomic double cfx_graph_last_at = 0;

BOOL cfx_graph_is_delivering(void) {
  return CFAbsoluteTimeGetCurrent() - cfx_graph_last_at < CFX_TAP_STALE_SECONDS;
}

static IMP cfx_orig_rqsn_render = NULL;

static void cfx_rqsn_render_tap(id self, SEL _cmd, CMSampleBufferRef sb, id input) {
  if (sb) cfx_graph_last_at = CFAbsoluteTimeGetCurrent();
  // Hold buffers only while a vcam preview is being pumped — never retain
  // graph buffers in clients without preview layers.
  if (sb && cfx_preview_has_layers()) cfx_tap_store(sb);
  typedef void (*Fn)(id, SEL, CMSampleBufferRef, id);
  ((Fn)cfx_orig_rqsn_render)(self, _cmd, sb, input);
}

void cfx_install_remote_queue_tap(void) {
  // Client-side tail of the capture graph. In this VM the synthetic source
  // is the only camera, so samples arriving here while a vcam preview is
  // tracked are ours by construction.
  Class cls = NSClassFromString(@"BWRemoteQueueSinkNode");
  if (!cls) { cfxlog(@"[tap] BWRemoteQueueSinkNode missing"); return; }
  SEL sel = @selector(renderSampleBuffer:forInput:);
  Method m = class_getInstanceMethod(cls, sel);
  if (!m) { cfxlog(@"[tap] renderSampleBuffer:forInput: missing"); return; }
  cfx_orig_rqsn_render = method_setImplementation(m, (IMP)cfx_rqsn_render_tap);
  cfxlog(@"[tap] installed BWRemoteQueueSinkNode tap (orig=%p)", cfx_orig_rqsn_render);
}
