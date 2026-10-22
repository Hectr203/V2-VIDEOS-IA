// No Audio Mix analysis on a guest that has no capture hardware.
//
// A spatial recording (Voice Memos on iOS 27 records first-order ambisonics,
// because the microphone source built from the product plist advertises
// cinematic audio) gets a BWAudioRemixAnalysisMetadataNode in its movie-file
// pipeline. The node calls -[AudioRemixSessionManager startNewSessionBlocking]
// to build a SoundAnalysis movie-remix session, and initialising that
// session's neural net faults in cameracaptured on the guest
// (BNNSGraphContextMakeStreaming, KERN_INVALID_ADDRESS 0x300), about 2 s into
// every recording.
//
// While the daemon runs on the microphone-only provider (no camera device: a
// VM), the method reports success without creating the session. Success, not
// an error: at a Stop marker the node starts the next session, and only when
// that succeeds does it forward the marker on its metadata output too
// (-renderSampleBuffer:forInput:, its .cold.7 / .cold.9); an error there
// leaves the movie-file sink waiting for a Stop that never comes. With no
// session the node still passes audio through: -submitAudioBuffer: is called
// only after -sessionReady, which stays NO, and
// -finishAndGetResultsBlockingWithStartingPTS:andEndingPTS: returns an error
// at once when there is no subscriber. The metadata track gets its format
// description and its markers and no samples. With a real capture device the
// method runs unchanged.
//
// The node's audio input is the recording's audio, so the same wrapper set
// logs its level while the guest has no capture hardware.
// See Research/Guest/ios27_capture_microphone_source.md §7.

#include <math.h>

#include "VCamCapturedPrivate.h"

// MARK: - session start

static IMP vcc_remix_start_orig = NULL;
static BOOL vcc_remix_skip_logged = NO;

static int vcc_remix_start_hook(id self, SEL _cmd) {
  if (!vcc_microphone_only_source_active()) {
    return ((int (*)(id, SEL))vcc_remix_start_orig)(self, _cmd);
  }
  if (!vcc_remix_skip_logged) {
    vcc_remix_skip_logged = YES;
    vcc_log(@"  mic source: no capture hardware; Audio Mix analysis session not created");
  }
  return 0;
}

// MARK: - recording level (diagnostic)

static IMP vcc_remix_render_orig = NULL;
static unsigned vcc_level_buffers = 0;
static unsigned vcc_level_zero_buffers = 0;
static uint64_t vcc_level_not_finite = 0;
static uint64_t vcc_level_frames = 0;
static float vcc_level_peak = 0;

static void vcc_measure_level(CMSampleBufferRef sbuf) {
  CMFormatDescriptionRef fd = CMSampleBufferGetFormatDescription(sbuf);
  if (!fd || CMFormatDescriptionGetMediaType(fd) != kCMMediaType_Audio) return;
  const AudioStreamBasicDescription *asbd =
      CMAudioFormatDescriptionGetStreamBasicDescription(fd);
  CMItemCount frames = CMSampleBufferGetNumSamples(sbuf);
  if (!asbd || frames <= 0) return;
  if (asbd->mFormatID != kAudioFormatLinearPCM ||
      !(asbd->mFormatFlags & kAudioFormatFlagIsFloat) ||
      asbd->mBitsPerChannel != 32) {
    static BOOL logged;
    if (!logged) {
      logged = YES;
      vcc_log(@"  remix input: format %u flags 0x%x %u bit, %u ch; level not measured",
              (unsigned)asbd->mFormatID, (unsigned)asbd->mFormatFlags,
              (unsigned)asbd->mBitsPerChannel, (unsigned)asbd->mChannelsPerFrame);
    }
    return;
  }

  size_t listSize = 0;
  if (CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
          sbuf, &listSize, NULL, 0, NULL, NULL, 0, NULL) != noErr ||
      listSize == 0) {
    return;
  }
  AudioBufferList *list = malloc(listSize);
  CMBlockBufferRef block = NULL;
  if (!list) return;
  if (CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
          sbuf, NULL, list, listSize, NULL, NULL,
          kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
          &block) == noErr) {
    float peak = 0;
    for (UInt32 b = 0; b < list->mNumberBuffers; b++) {
      const float *s = list->mBuffers[b].mData;
      size_t n = list->mBuffers[b].mDataByteSize / sizeof(float);
      for (size_t i = 0; s && i < n; i++) {
        // A NaN compares false with everything and would read as silence.
        if (!isfinite(s[i])) {
          vcc_level_not_finite++;
          continue;
        }
        float v = fabsf(s[i]);
        if (v > peak) peak = v;
      }
    }
    vcc_level_buffers++;
    vcc_level_frames += (uint64_t)frames;
    if (peak == 0) vcc_level_zero_buffers++;
    if (peak > vcc_level_peak) vcc_level_peak = peak;
    // About every 2 s at 48 kHz.
    if (vcc_level_frames >= 96000) {
      vcc_log(@"  remix input: %u ch, %u buffers, %llu frames, %u all zero, %llu samples not finite, peak %.1f dBFS",
              (unsigned)asbd->mChannelsPerFrame, vcc_level_buffers,
              (unsigned long long)vcc_level_frames, vcc_level_zero_buffers,
              (unsigned long long)vcc_level_not_finite,
              vcc_level_peak > 0 ? 20 * log10f(vcc_level_peak) : -INFINITY);
      vcc_level_buffers = vcc_level_zero_buffers = 0;
      vcc_level_frames = 0;
      vcc_level_not_finite = 0;
      vcc_level_peak = 0;
    }
  }
  if (block) CFRelease(block);
  free(list);
}

static void vcc_remix_render_hook(id self, SEL _cmd, CMSampleBufferRef sbuf,
                                  id input) {
  if (sbuf && vcc_microphone_only_source_active()) vcc_measure_level(sbuf);
  ((void (*)(id, SEL, CMSampleBufferRef, id))vcc_remix_render_orig)(
      self, _cmd, sbuf, input);
}

// MARK: - install

void vcc_install_remix_session_skip(void) {
  Class cls = NSClassFromString(@"AudioRemixSessionManager");
  SEL sel = NSSelectorFromString(@"startNewSessionBlocking");
  Method m = cls ? class_getInstanceMethod(cls, sel) : NULL;
  if (!m) {
    vcc_log(@"  remix: -[AudioRemixSessionManager startNewSessionBlocking] missing");
    return;
  }
  // The node branches on a 32-bit status (cbnz w0); refuse any other shape.
  const char *types = method_getTypeEncoding(m);
  if (!types || (types[0] != 'i' && types[0] != 'I')) {
    vcc_log(@"  remix: startNewSessionBlocking has type %s, not wrapped",
            types ?: "?");
    return;
  }
  vcc_remix_start_orig = method_setImplementation(m, (IMP)vcc_remix_start_hook);
  vcc_log(@"  remix: wrapped -[AudioRemixSessionManager startNewSessionBlocking] (orig imp=%p)",
          vcc_remix_start_orig);

  Class node = NSClassFromString(@"BWAudioRemixAnalysisMetadataNode");
  Method r = node ? class_getInstanceMethod(
                        node, NSSelectorFromString(@"renderSampleBuffer:forInput:"))
                  : NULL;
  // Only the node's own override; never rewrite an inherited BWNode method.
  if (r && r != class_getInstanceMethod(class_getSuperclass(node),
                                        method_getName(r))) {
    vcc_remix_render_orig = method_setImplementation(r, (IMP)vcc_remix_render_hook);
    vcc_log(@"  remix: measuring -[BWAudioRemixAnalysisMetadataNode renderSampleBuffer:forInput:] input");
  }
}
