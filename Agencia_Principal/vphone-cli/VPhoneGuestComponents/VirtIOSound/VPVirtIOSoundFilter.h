// VPVirtIOSoundFilter.h — the low cut on what the host's microphone captures.
//
// A phone's microphone does not pick up much below 100 Hz, and the tunings
// iOS records through are built on that: the D47 set's only high-pass is at
// 30 Hz. The Mac's built-in microphone, taken as Virtualization hands it
// over, carries the machine's own rumble instead. Measured in the pauses of a
// capture: -55 to -57 dBFS in each of the bands from 40 to 150 Hz, against
// -67 dBFS and lower above 250 Hz — a recording that sounds like wind.
//
// The filter is a fourth-order Butterworth high-pass, two biquads in
// transposed direct form II, run over each captured period before the HAL
// reads it. It is not real-time code: the input stream calls it from its
// completion queue.

#ifndef VPVirtIOSoundFilter_h
#define VPVirtIOSoundFilter_h

#include <stdint.h>

enum {
    kVPVirtIOSoundHighPassSections = 2,
    kVPVirtIOSoundHighPassChannels = 2,
};

typedef struct {
    /// Per section: b0, b1, b2, a1, a2, with a0 normalized to 1.
    double coefficients[kVPVirtIOSoundHighPassSections][5];
    double state[kVPVirtIOSoundHighPassChannels][kVPVirtIOSoundHighPassSections][2];
} VPVirtIOSoundHighPass;

/// Set the filter up for `cutoff` Hz at `sampleRate`, with its state clear.
void VPVirtIOSoundHighPassConfigure(VPVirtIOSoundHighPass *filter, double sampleRate, double cutoff);

/// Forget what the filter has seen, for a run that starts on new audio.
void VPVirtIOSoundHighPassReset(VPVirtIOSoundHighPass *filter);

/// Filter `frames` interleaved Float32 frames of `channels` channels in
/// place. Channels past `kVPVirtIOSoundHighPassChannels` are left as they are.
void VPVirtIOSoundHighPassProcess(VPVirtIOSoundHighPass *filter, float *samples, uint32_t frames,
    uint32_t channels);

#endif /* VPVirtIOSoundFilter_h */
