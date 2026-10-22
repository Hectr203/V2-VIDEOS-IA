// VPVirtIOSoundConverter.c — see the header.

#include "VPVirtIOSoundConverter.h"

void VPVirtIOSoundConverterReset(VPVirtIOSoundConverter *converter,
    uint32_t inputRate, uint32_t outputRate, uint32_t channels) {
    converter->inputRate = inputRate;
    converter->outputRate = outputRate;
    converter->channels = channels;
    for (uint32_t channel = 0; channel < kVPVirtIOSoundConverterMaximumChannels; channel++) {
        converter->last[channel] = 0;
        converter->current[channel] = 0;
    }
    // Two frames past the empty pair: the first output frame needs both of
    // its neighbours, and with them in place it is the first of them.
    converter->phase = 2 * (uint64_t)outputRate;
}

uint32_t VPVirtIOSoundConverterInputFrames(const VPVirtIOSoundConverter *converter, uint32_t outputFrames) {
    if (outputFrames == 0) {
        return 0;
    }
    // The pair moves on once for every whole wire frame the last output
    // frame's position has passed.
    return (uint32_t)((converter->phase + (uint64_t)(outputFrames - 1) * converter->inputRate)
        / converter->outputRate);
}

void VPVirtIOSoundConverterProcess(VPVirtIOSoundConverter *converter,
    const float *input, float *output, uint32_t outputFrames) {
    const uint32_t channels = converter->channels;
    const uint64_t inputRate = converter->inputRate;
    const uint64_t outputRate = converter->outputRate;
    uint64_t phase = converter->phase;
    uint32_t produced = 0;
    while (produced < outputFrames) {
        if (phase >= outputRate) {
            phase -= outputRate;
            for (uint32_t channel = 0; channel < channels; channel++) {
                converter->last[channel] = converter->current[channel];
                converter->current[channel] = input[channel];
            }
            input += channels;
            continue;
        }
        const float fraction = (float)phase / (float)outputRate;
        for (uint32_t channel = 0; channel < channels; channel++) {
            output[channel] = converter->last[channel]
                + (converter->current[channel] - converter->last[channel]) * fraction;
        }
        output += channels;
        produced++;
        phase += inputRate;
    }
    converter->phase = phase;
}
