#ifndef VCAM_SYNTHETIC_H
#define VCAM_SYNTHETIC_H

// The synthetic camera: its FigCaptureSourceBacking, the source appended
// to the daemon's source list, and the BWFigCaptureDevice /
// BWFigCaptureStream subclasses the device vendor hands out for it.

#include "VCamCapturedPrivate.h"

#pragma GCC visibility push(hidden)

// Published as the synthetic source's CaptureDeviceID attribute, and matched
// against by the -[BWFigCaptureDeviceVendor copyDeviceWithID:…] hook. One
// definition: the two must stay identical or the device lookup stops matching.
extern NSString *const kVccSynthDeviceID;

// Opaque unique ID of the one realtime video stream this source publishes.
extern NSString *const kVccSynthStreamID;

// The FigCaptureSourceBacking describing the synthetic source (attributes
// and formats), or nil when a required class or key is missing.
id vcc_build_backing(void);

// VccSynthDevice, registered on first use; Nil until then or on failure.
extern Class vcc_synth_device_class;

// Offset of BWFigCaptureDevice's deviceID ivar; -1 until resolved.
extern ptrdiff_t kBWFigCaptureDevice_deviceID_Offset;

// Offset of the first ivar in `names` (NULL-terminated) found on cls, or -1.
ptrdiff_t vcc_resolve_ivar(Class cls, const char *what, const char *const *names);

#pragma GCC visibility pop

#endif
