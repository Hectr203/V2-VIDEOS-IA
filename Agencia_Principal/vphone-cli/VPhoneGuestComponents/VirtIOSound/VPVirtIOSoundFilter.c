// VPVirtIOSoundFilter.c — see VPVirtIOSoundFilter.h.

#include "VPVirtIOSoundFilter.h"

#include <math.h>
#include <string.h>

/// The quality factors of a fourth-order Butterworth's two sections:
/// 1 / (2 cos(pi/8)) and 1 / (2 cos(3 pi/8)).
static const double kSectionQ[kVPVirtIOSoundHighPassSections] = {0.54119610014619698, 1.3065629648763766};

void VPVirtIOSoundHighPassConfigure(VPVirtIOSoundHighPass *filter, double sampleRate, double cutoff) {
    double omega = 2 * M_PI * cutoff / sampleRate;
    double cosine = cos(omega);
    for (int section = 0; section < kVPVirtIOSoundHighPassSections; section++) {
        double alpha = sin(omega) / (2 * kSectionQ[section]);
        double a0 = 1 + alpha;
        double *c = filter->coefficients[section];
        c[0] = (1 + cosine) / 2 / a0;
        c[1] = -(1 + cosine) / a0;
        c[2] = (1 + cosine) / 2 / a0;
        c[3] = -2 * cosine / a0;
        c[4] = (1 - alpha) / a0;
    }
    VPVirtIOSoundHighPassReset(filter);
}

void VPVirtIOSoundHighPassReset(VPVirtIOSoundHighPass *filter) {
    memset(filter->state, 0, sizeof(filter->state));
}

void VPVirtIOSoundHighPassProcess(VPVirtIOSoundHighPass *filter, float *samples, uint32_t frames,
    uint32_t channels) {
    uint32_t filtered = channels < kVPVirtIOSoundHighPassChannels ? channels : kVPVirtIOSoundHighPassChannels;
    for (uint32_t channel = 0; channel < filtered; channel++) {
        for (int section = 0; section < kVPVirtIOSoundHighPassSections; section++) {
            const double *c = filter->coefficients[section];
            double z1 = filter->state[channel][section][0];
            double z2 = filter->state[channel][section][1];
            for (uint32_t frame = 0; frame < frames; frame++) {
                float *sample = &samples[(size_t)frame * channels + channel];
                double input = *sample;
                // What is not a number would stay in the state for good.
                if (!isfinite(input)) {
                    input = 0;
                }
                double output = c[0] * input + z1;
                z1 = c[1] * input - c[3] * output + z2;
                z2 = c[2] * input - c[4] * output;
                *sample = (float)output;
            }
            filter->state[channel][section][0] = z1;
            filter->state[channel][section][1] = z2;
        }
    }
}
