#ifndef VCAM_CAPTURED_PRIVATE_H
#define VCAM_CAPTURED_PRIVATE_H

// Shared by every libvcamcaptured translation unit. Each subsystem folder
// has its own header for the state and helpers it owns; this one holds the
// dylib-wide helpers and the install entry points the constructor calls.
//
// Everything declared between the visibility pragmas is internal to the
// dylib: it links across files but stays out of the export table.

#import <CoreFoundation/CoreFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "VCamFrameProtocol.h"

#pragma GCC visibility push(hidden)

// MARK: - logging and swizzling

// Appends one line to VPHONE_VCAM_CAPTURE_LOG_PATH and mirrors it to NSLog.
void vcc_log(NSString *fmt, ...);

// Replaces -[cls sel] with newImp and stores the previous IMP in *outOrig.
// Logs and leaves *outOrig untouched when the method is missing.
void vcc_swizzle_method(Class cls, SEL sel, IMP newImp, IMP *outOrig);

// MARK: - install entry points (called once from the constructor)

// Serves the microphone's capture source when the daemon could not build
// its built-in sources (no camera device on a VM). Installed synchronously
// in the constructor, before the daemon's first source query.
void vcc_install_microphone_source(void);

// YES once the daemon has been served the microphone-only provider, which
// happens only when it has no capture device of its own.
BOOL vcc_microphone_only_source_active(void);

// While that provider is in use, -[AudioRemixSessionManager
// startNewSessionBlocking] reports success without creating the Audio Mix
// session whose neural net faults on a guest, and the remix node's audio
// input level is logged.
void vcc_install_remix_session_skip(void);

void vcc_install_synthetic(void);
void vcc_start_frame_receiver(void);
void vcc_install_endpoint_hook(void);
void vcc_install_sink_observation(void);
void vcc_install_still_sink_observation(void);
void vcc_install_session_graph_observation(void);
void vcc_install_still_coordinator_observation(void);
void vcc_install_still_coord_node_observation(void);
void vcc_install_still_pipeline_observation(void);
void vcc_install_pipelines_addStill_observation(void);
void vcc_install_parsed_cfg_observation(void);
void vcc_install_csp_requires_master_clock_hook(void);
void vcc_install_session_init_capture(void);
void vcc_construct_still_sink(void);
void vcc_drive_still_sink_once(void);
void vcc_install_viewfinder_hooks(void);
void vcc_dump_sink_node_methods(void);
void vcc_install_device_vendor_hook(void);
void vcc_install_copy_streams_hook(void);
void vcc_install_copy_streams_from_hook(void);

// On the paravirtual GPU, removes the daemon's call to PrewarmThreadSafeSBPs,
// whose NRF prewarm faults in the guest's Metal driver. Installed
// synchronously in the constructor, before the daemon starts its preload.
void vcc_install_gpu_prewarm_skip(void);

#pragma GCC visibility pop

#endif
