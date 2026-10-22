// Frames delivered straight to AVCaptureVideoDataOutput delegates of vcam
// sessions whose capture graph never runs.

#import "CamFixPrivate.h"

// MARK: - client-side video delivery for vcam sessions
//
// When a session's capture graph never runs, its AVCaptureVideoDataOutput
// delegates starve. Deliver the shared-layer sample directly to the
// delegate on the output's own callback queue — the same pattern as the
// photo delivery path. In this VM the synthetic source is the only camera,
// so any vcam session's data output is ours. Stops while the graph
// delivers (see cfx_graph_is_delivering).

static NSHashTable *cfx_vcam_sessions = nil;  // weak, guarded
static pthread_mutex_t cfx_vcam_sessions_lock = PTHREAD_MUTEX_INITIALIZER;
static uint64_t cfx_video_deliver_count = 0;
static _Atomic uint64_t cfx_video_deliver_ok = 0;
static _Atomic int cfx_video_deliver_logged = 0;

// Also arms the 30 Hz pump: a session with a data output and no preview
// layer would otherwise never start it.
void cfx_track_vcam_session(id session) {
  if (!session) return;
  BOOL added = NO;
  pthread_mutex_lock(&cfx_vcam_sessions_lock);
  if (!cfx_vcam_sessions) cfx_vcam_sessions = [NSHashTable weakObjectsHashTable];
  if (![cfx_vcam_sessions containsObject:session]) {
    [cfx_vcam_sessions addObject:session];
    added = YES;
  }
  pthread_mutex_unlock(&cfx_vcam_sessions_lock);
  if (!added) return;
  cfxlog(@"[video delivery] tracking session %p", session);
  dispatch_async(dispatch_get_main_queue(), ^{ cfx_preview_start_timer(); });
}

void cfx_deliver_video_frames_once(void) {
  pthread_mutex_lock(&cfx_vcam_sessions_lock);
  NSArray *sessions = cfx_vcam_sessions.allObjects;
  pthread_mutex_unlock(&cfx_vcam_sessions_lock);
  if (sessions.count == 0 || cfx_graph_is_delivering()) return;
  Class dataOutCls = NSClassFromString(@"AVCaptureVideoDataOutput");
  if (!dataOutCls) return;

  for (id sess in sessions) {
    NSArray *outputs = nil;
    @try { outputs = [sess valueForKey:@"outputs"]; } @catch (NSException *e) { continue; }
    for (id out in outputs) {
      if (![out isKindOfClass:dataOutCls]) continue;
      id delegate = nil;
      dispatch_queue_t q = nil;
      @try { delegate = [out valueForKey:@"sampleBufferDelegate"]; } @catch (NSException *e) {}
      @try { q = [out valueForKey:@"sampleBufferCallbackQueue"]; } @catch (NSException *e) {}
      if (!delegate) continue;
      NSArray *conns = nil;
      @try { conns = [out valueForKey:@"connections"]; } @catch (NSException *e) {}
      for (id conn in conns) {
        BOOL enabled = NO;
        @try { enabled = [[conn valueForKey:@"enabled"] boolValue]; } @catch (NSException *e) {}
        if (!enabled) continue;
        CMSampleBufferRef sb = cfx_build_cmsb();
        if (!sb) continue;
        cfx_video_deliver_count++;
        dispatch_async(q ?: dispatch_get_main_queue(), ^{
          @autoreleasepool {
            @try {
              ((void (*)(id, SEL, id, CMSampleBufferRef, id))objc_msgSend)(
                  delegate,
                  @selector(captureOutput:didOutputSampleBuffer:fromConnection:),
                  out,
                  sb,
                  conn);
              cfx_video_deliver_ok++;
            } @catch (NSException *e) {
              if (cfx_video_deliver_logged++ < 8) {
                cfxlog(@"[video delivery] delegate exception: %@", e);
              }
            }
            CFRelease(sb);
          }
        });
      }
    }
  }
  if (cfx_video_deliver_count && (cfx_video_deliver_count % 90) == 1) {
    cfxlog(@"[video delivery] attempted=%llu ok=%llu",
           (unsigned long long)cfx_video_deliver_count,
           (unsigned long long)cfx_video_deliver_ok);
  }
}
