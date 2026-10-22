// VPVirtIOSoundLatency.c — see VPVirtIOSoundLatency.h.

#include "VPVirtIOSoundLatency.h"

#include <math.h>

void VPVirtIOSoundLatencyTrackerInit(VPVirtIOSoundLatencyTracker *tracker, uint32_t floorPeriods,
    uint32_t risingWindows, uint32_t fallingWindows) {
    *tracker = (VPVirtIOSoundLatencyTracker){
        .floorPeriods = floorPeriods,
        .risingWindows = risingWindows > 0 ? risingWindows : 1,
        .fallingWindows = fallingWindows > 0 ? fallingWindows : 1,
        .periods = floorPeriods,
    };
}

bool VPVirtIOSoundLatencyTrackerAddWindow(VPVirtIOSoundLatencyTracker *tracker, uint32_t maximumInFlightPeriods) {
    // The period being filled sits in the ring behind everything in flight.
    uint32_t wanted = maximumInFlightPeriods + 1;
    if (wanted < tracker->floorPeriods) {
        wanted = tracker->floorPeriods;
    }
    if (wanted > tracker->periods) {
        tracker->fallingCount = 0;
        tracker->risingPeriods = tracker->risingCount == 0 || wanted < tracker->risingPeriods
            ? wanted : tracker->risingPeriods;
        if (++tracker->risingCount < tracker->risingWindows) {
            return false;
        }
        tracker->periods = tracker->risingPeriods;
    } else if (wanted < tracker->periods) {
        tracker->risingCount = 0;
        tracker->fallingPeriods = tracker->fallingCount == 0 || wanted > tracker->fallingPeriods
            ? wanted : tracker->fallingPeriods;
        if (++tracker->fallingCount < tracker->fallingWindows) {
            return false;
        }
        tracker->periods = tracker->fallingPeriods;
    } else {
        tracker->risingCount = 0;
        tracker->fallingCount = 0;
        return false;
    }
    tracker->risingCount = 0;
    tracker->fallingCount = 0;
    return true;
}

uint32_t VPVirtIOSoundLatencyPeriods(uint64_t bytes, uint32_t periodBytes) {
    if (periodBytes == 0) {
        return 0;
    }
    uint64_t periods = (bytes + periodBytes - 1) / periodBytes;
    return periods > UINT32_MAX ? UINT32_MAX : (uint32_t)periods;
}

uint32_t VPVirtIOSoundLatencyFrames(uint32_t queuedWireFrames, double wireRate, double nominalRate,
    double hostSeconds) {
    if (!(wireRate > 0) || !(nominalRate > 0)) {
        return queuedWireFrames;
    }
    double host = hostSeconds > 0 ? fmin(hostSeconds, kVPVirtIOSoundMaximumHostLatency) : 0;
    double frames = (double)queuedWireFrames * nominalRate / wireRate + host * nominalRate;
    return frames >= (double)UINT32_MAX ? UINT32_MAX : (uint32_t)lround(frames);
}
