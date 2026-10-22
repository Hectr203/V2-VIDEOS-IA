// VirtIOSoundConverterTests.c — host checks for the capture rate converter:
// how many wire frames a read takes, and what the frames it produces are.

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "VPVirtIOSoundConverter.h"

static int failures;

#define CHECK(condition)                                                       \
    do {                                                                       \
        if (!(condition)) {                                                    \
            fprintf(stderr, "%s:%d: CHECK(%s) failed\n", __FILE__, __LINE__,   \
                #condition);                                                   \
            failures++;                                                        \
        }                                                                      \
    } while (0)

/// The wire signal: a ramp, so a frame interpolated at position p is p on
/// the first channel and -p on the second.
static void fillRamp(float *frames, uint32_t first, uint32_t count, uint32_t channels) {
    for (uint32_t i = 0; i < count; i++) {
        frames[i * channels] = (float)(first + i);
        if (channels > 1) {
            frames[i * channels + 1] = -(float)(first + i);
        }
    }
}

/// Reads `total` frames in blocks of the sizes given, cycling through them,
/// and returns the wire frames taken. Every frame is checked against the
/// ramp's value where it falls.
static uint64_t readRamp(VPVirtIOSoundConverter *converter, uint32_t channels,
    const uint32_t *blocks, uint32_t blockCount, uint64_t total) {
    static float input[4096 * 2];
    static float output[2048 * 2];
    const double step = (double)converter->inputRate / converter->outputRate;
    uint64_t taken = 0;
    uint64_t produced = 0;
    for (uint32_t turn = 0; produced < total; turn++) {
        uint32_t block = blocks[turn % blockCount];
        uint32_t needed = VPVirtIOSoundConverterInputFrames(converter, block);
        CHECK(needed <= 4096);
        fillRamp(input, (uint32_t)taken, needed, channels);
        VPVirtIOSoundConverterProcess(converter, input, output, block);
        for (uint32_t i = 0; i < block; i++) {
            double expected = (double)(produced + i) * step;
            // At the far end of the ramp a float is good to 1/32, and a frame
            // taken from the wrong place would be off by a whole one; the
            // interpolation is checked to a tenth.
            CHECK(fabs(output[i * channels] - expected) < 0.1);
            if (channels > 1) {
                CHECK(fabs(output[i * channels + 1] + expected) < 0.1);
            }
        }
        taken += needed;
        produced += block;
    }
    return taken;
}

static void testFirstFrameIsTheFirstWireFrame(void) {
    VPVirtIOSoundConverter converter;
    VPVirtIOSoundConverterReset(&converter, 48000, 44100, 1);
    CHECK(VPVirtIOSoundConverterInputFrames(&converter, 0) == 0);
    // One frame out needs both of its neighbours.
    CHECK(VPVirtIOSoundConverterInputFrames(&converter, 1) == 2);
    float input[2] = {7, 9};
    float output[1] = {0};
    VPVirtIOSoundConverterProcess(&converter, input, output, 1);
    CHECK(output[0] == 7);
    // The next lies 48000/44100 of a wire frame on, past the second.
    CHECK(VPVirtIOSoundConverterInputFrames(&converter, 1) == 1);
}

static void testTakesWireFramesAtTheRatioOfTheRates(void) {
    VPVirtIOSoundConverter converter;
    VPVirtIOSoundConverterReset(&converter, 48000, 44100, 2);
    const uint32_t blocks[] = {512, 1, 441, 1024, 37};
    // Ten seconds: the two frames the start takes ahead, then 48000 wire
    // frames for every 44100 read, give or take the one in progress.
    uint64_t taken = readRamp(&converter, 2, blocks, 5, 441000);
    CHECK(taken >= 480000 && taken <= 480000 + 1200);
    uint64_t again = readRamp(&converter, 2, blocks, 5, 0);
    CHECK(again == 0);
}

static void testSameFramesWhateverTheBlockSize(void) {
    VPVirtIOSoundConverter whole, pieces;
    VPVirtIOSoundConverterReset(&whole, 48000, 44100, 1);
    VPVirtIOSoundConverterReset(&pieces, 48000, 44100, 1);
    const uint32_t one[] = {1470};
    const uint32_t odd[] = {1, 7, 333, 2, 1127};
    uint64_t takenWhole = readRamp(&whole, 1, one, 1, 1470);
    uint64_t takenPieces = readRamp(&pieces, 1, odd, 5, 1470);
    CHECK(takenWhole == takenPieces);
    CHECK(whole.phase == pieces.phase);
    CHECK(whole.current[0] == pieces.current[0]);
}

static void testGoesUpAsWellAsDown(void) {
    VPVirtIOSoundConverter converter;
    VPVirtIOSoundConverterReset(&converter, 44100, 48000, 1);
    const uint32_t blocks[] = {480, 33};
    uint64_t taken = readRamp(&converter, 1, blocks, 2, 48000);
    CHECK(taken >= 44100 && taken <= 44100 + 520);
}

int main(void) {
    testFirstFrameIsTheFirstWireFrame();
    testTakesWireFramesAtTheRatioOfTheRates();
    testSameFramesWhateverTheBlockSize();
    testGoesUpAsWellAsDown();
    if (failures) {
        fprintf(stderr, "VirtIOSoundConverterTests: %d failure(s)\n", failures);
        return 1;
    }
    printf("VirtIOSoundConverterTests: all passed\n");
    return 0;
}
