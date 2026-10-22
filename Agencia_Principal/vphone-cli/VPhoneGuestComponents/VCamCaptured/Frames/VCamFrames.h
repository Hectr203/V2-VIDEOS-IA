#ifndef VCAM_FRAMES_H
#define VCAM_FRAMES_H

// The latest frame vphoned published, and the CMSampleBuffers built from
// it for every sink this dylib drives.

#include "VCamCapturedPrivate.h"

#pragma GCC visibility push(hidden)

// The latest frame copied out of the vphoned-published shm. Written only by
// the frame receiver's queue (VCamFrameReceiver.m); readers take the lock
// for the brief duration of a copy.
typedef struct vcc_latest_frame_s {
  pthread_mutex_t lock;
  uint32_t width;
  uint32_t height;
  uint32_t bytes_per_row;
  uint32_t pixel_format;
  uint64_t timestamp_ns;
  uint64_t frame_index;
  uint8_t *pixels;
  size_t   pixels_capacity;
  size_t   pixels_length;
} vcc_latest_frame_t;

extern vcc_latest_frame_t vcc_latest_frame;

// A CMSampleBuffer wrapping the latest frame in fmt_out (VCC_FMT_*), or
// NULL when no frame has arrived. Caller must CFRelease.
CMSampleBufferRef vcc_build_cmsb_from_shm_fmt(uint32_t fmt_out) CF_RETURNS_RETAINED;

// A frame consumer (viewfinder stream or video sink) appeared: run the 30 Hz
// drive until none is left (VCamDriveGate.h).
void vcc_frame_drive_wake(void);

#pragma GCC visibility pop

#endif
