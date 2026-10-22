#ifndef VCAM_HOOKS_H
#define VCAM_HOOKS_H

// Observation and delivery hooks on the daemon's capture graph classes.

#include "VCamCapturedPrivate.h"

#pragma GCC visibility push(hidden)

// Every video sink node (BWImageQueueSinkNode / BWRemoteQueueSinkNode)
// created so far, as an immutable snapshot the viewfinder drive delivers to.
NSArray *vcc_driven_sinks_snapshot(void);

#pragma GCC visibility pop

#endif
