// VPVirtIOSoundConverter.h — captured frames at another rate than the wire's.
//
// The virtio stream captures at one rate, the wire rate. A session that plays
// and records at the speaker's other rate reads the microphone at that rate
// too, so what the ring holds is converted as it is read: the frames a read
// asks for are interpolated, in a straight line, from the wire frames around
// them. That is the speaker path's conversion turned around. It filters
// nothing first: going down from 48000 to 44100 folds what lies above
// 22050 Hz back, which a microphone has next to none of.
//
// A pull converter: the caller asks how many wire frames the next read
// takes, fetches exactly those, and hands them over. The phase is kept in
// whole units of 1/outputRate of a wire frame, so the count is exact and the
// long-run ratio is the ratio of the rates.

#ifndef VPVirtIOSoundConverter_h
#define VPVirtIOSoundConverter_h

#include <stdint.h>

enum { kVPVirtIOSoundConverterMaximumChannels = 2 };

typedef struct {
    uint32_t inputRate;
    uint32_t outputRate;
    uint32_t channels;
    /// The two wire frames the next output frame lies between.
    float last[kVPVirtIOSoundConverterMaximumChannels];
    float current[kVPVirtIOSoundConverterMaximumChannels];
    /// Where it lies between them, in 1/outputRate of a wire frame. At or
    /// past outputRate the pair moves on before anything is produced.
    uint64_t phase;
} VPVirtIOSoundConverter;

/// Start over: the first output frame is the first wire frame handed over.
/// `channels` is 1 or 2, interleaved 32-bit float.
void VPVirtIOSoundConverterReset(VPVirtIOSoundConverter *converter,
    uint32_t inputRate, uint32_t outputRate, uint32_t channels);

/// The wire frames the next `outputFrames` frames take.
uint32_t VPVirtIOSoundConverterInputFrames(const VPVirtIOSoundConverter *converter, uint32_t outputFrames);

/// Produce `outputFrames` frames from `input`, which holds exactly
/// `VPVirtIOSoundConverterInputFrames(converter, outputFrames)` wire frames.
/// Real-time safe.
void VPVirtIOSoundConverterProcess(VPVirtIOSoundConverter *converter,
    const float *input, float *output, uint32_t outputFrames);

#endif /* VPVirtIOSoundConverter_h */
