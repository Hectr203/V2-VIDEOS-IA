// VPVirtIOSoundLatency.h — the speaker's output latency, from what is queued
// ahead of the host and what the Mac's output device adds after it.
//
// A player presents its picture the device's output latency after it writes
// the matching sound, so the latency has to be the time from the HAL's write
// to the listener's ear. Two parts of that live in the guest's view:
//
// - What the stream keeps queued ahead of the host: the frames waiting in
//   the ring for a whole period, and the periods the virtio device holds and
//   has not returned (`in flight`). Virtualization's host sink keeps more in
//   flight for some output devices than others: measured, 1-2 periods with
//   the Mac's built-in speakers and 3-5 (up to 8) with AirPods. The tracker
//   below follows it.
// - What the Mac's output device adds after its mixer: the device's and its
//   stream's latency. vphone-vm reads
//   that from CoreAudio and vphoned stores it for the plugin, in seconds.
//
// The tracker sees the most in flight per window of a few seconds. The
// queued figure is that plus the period being filled, never below the lead
// plus one period that the stream queues at each start. A change costs the
// HAL a configuration change, which stops and restarts I/O, so it moves only
// when several windows in a row agree: up after `risingWindows` windows that
// all ask for more (to the least of them, so one burst does not count), down
// after `fallingWindows` windows that all ask for less (to the most of them).
// A window that matches the current figure starts both counts over.
//
// Not real-time code: the stream feeds it from its own queue.

#ifndef VPVirtIOSoundLatency_h
#define VPVirtIOSoundLatency_h

#include <stdbool.h>
#include <stdint.h>

/// The most host latency taken from the setting, in seconds. A Bluetooth
/// output is a few hundred milliseconds; anything past this is a bad value.
#define kVPVirtIOSoundMaximumHostLatency 1.0

typedef struct {
    uint32_t floorPeriods;
    uint32_t risingWindows;
    uint32_t fallingWindows;
    /// The periods queued ahead of the host as currently reported.
    uint32_t periods;
    /// The windows in a row that asked for more, or for less, than `periods`,
    /// and the figure they agree on so far.
    uint32_t risingCount;
    uint32_t risingPeriods;
    uint32_t fallingCount;
    uint32_t fallingPeriods;
} VPVirtIOSoundLatencyTracker;

/// Starts the tracker at `floorPeriods`, the lead plus one period.
void VPVirtIOSoundLatencyTrackerInit(VPVirtIOSoundLatencyTracker *tracker, uint32_t floorPeriods,
    uint32_t risingWindows, uint32_t fallingWindows);

/// Feeds one window, given the most periods in flight any write in it found.
/// Returns true when `periods` changed.
bool VPVirtIOSoundLatencyTrackerAddWindow(VPVirtIOSoundLatencyTracker *tracker, uint32_t maximumInFlightPeriods);

/// Whole periods covering `bytes`; a draining run can leave a partial one.
uint32_t VPVirtIOSoundLatencyPeriods(uint64_t bytes, uint32_t periodBytes);

/// The device's output latency in frames of `nominalRate`: `queuedWireFrames`
/// at the virtio wire rate plus `hostSeconds` (clamped to 0 through
/// `kVPVirtIOSoundMaximumHostLatency`; not a number counts as 0), rounded to
/// the nearest frame.
uint32_t VPVirtIOSoundLatencyFrames(uint32_t queuedWireFrames, double wireRate, double nominalRate,
    double hostSeconds);

#endif /* VPVirtIOSoundLatency_h */
