// VirtIOSoundLatencyTests.c — host checks for the speaker's reported output
// latency: the queued figure's hysteresis and the arithmetic into frames.

#include <math.h>
#include <stdio.h>

#include "VPVirtIOSoundLatency.h"

static int failures;

#define CHECK(condition)                                                       \
    do {                                                                       \
        if (!(condition)) {                                                    \
            fprintf(stderr, "%s:%d: CHECK(%s) failed\n", __FILE__, __LINE__,   \
                #condition);                                                   \
            failures++;                                                        \
        }                                                                      \
    } while (0)

/// The plugin's defaults: a lead of 2 periods, so a floor of 3; up after two
/// windows, down after twelve.
static VPVirtIOSoundLatencyTracker defaultTracker(void) {
    VPVirtIOSoundLatencyTracker tracker;
    VPVirtIOSoundLatencyTrackerInit(&tracker, 3, 2, 12);
    return tracker;
}

/// The built-in speakers keep 1-2 periods in flight: the floor already
/// covers that, and nothing changes however long it runs.
static void testBuiltInStaysAtTheFloor(void) {
    VPVirtIOSoundLatencyTracker tracker = defaultTracker();
    CHECK(tracker.periods == 3);
    for (int window = 0; window < 100; window++) {
        CHECK(!VPVirtIOSoundLatencyTrackerAddWindow(&tracker, (uint32_t)(window % 3)));
    }
    CHECK(tracker.periods == 3);
}

/// AirPods keep 3-5 in flight: two windows that both ask for more move it,
/// to the lesser of the two.
static void testRisesAfterTwoWindowsToTheLesser(void) {
    VPVirtIOSoundLatencyTracker tracker = defaultTracker();
    CHECK(!VPVirtIOSoundLatencyTrackerAddWindow(&tracker, 7));
    CHECK(tracker.periods == 3);
    CHECK(VPVirtIOSoundLatencyTrackerAddWindow(&tracker, 5));
    CHECK(tracker.periods == 6);
    // Settled there: windows that match change nothing.
    CHECK(!VPVirtIOSoundLatencyTrackerAddWindow(&tracker, 5));
    CHECK(!VPVirtIOSoundLatencyTrackerAddWindow(&tracker, 5));
    CHECK(tracker.periods == 6);
}

/// One burst between ordinary windows does not move it.
static void testSingleBurstIsIgnored(void) {
    VPVirtIOSoundLatencyTracker tracker = defaultTracker();
    for (int round = 0; round < 10; round++) {
        CHECK(!VPVirtIOSoundLatencyTrackerAddWindow(&tracker, 8));
        CHECK(!VPVirtIOSoundLatencyTrackerAddWindow(&tracker, 2));
    }
    CHECK(tracker.periods == 3);
}

/// Down only after twelve windows in a row ask for less, to the most of
/// them; one window at the current figure starts the count over.
static void testFallsSlowly(void) {
    VPVirtIOSoundLatencyTracker tracker = defaultTracker();
    VPVirtIOSoundLatencyTrackerAddWindow(&tracker, 6);
    VPVirtIOSoundLatencyTrackerAddWindow(&tracker, 6);
    CHECK(tracker.periods == 7);
    for (int window = 0; window < 11; window++) {
        CHECK(!VPVirtIOSoundLatencyTrackerAddWindow(&tracker, 2));
    }
    CHECK(!VPVirtIOSoundLatencyTrackerAddWindow(&tracker, 6));
    CHECK(tracker.periods == 7);
    for (int window = 0; window < 11; window++) {
        CHECK(!VPVirtIOSoundLatencyTrackerAddWindow(&tracker, window == 4 ? 3 : 1));
    }
    CHECK(VPVirtIOSoundLatencyTrackerAddWindow(&tracker, 1));
    CHECK(tracker.periods == 4);
    // Never below the floor, whatever is in flight.
    for (int window = 0; window < 12; window++) {
        VPVirtIOSoundLatencyTrackerAddWindow(&tracker, 0);
    }
    CHECK(tracker.periods == 3);
}

/// A window that does not ask for more clears a rise in progress.
static void testOppositeWindowResetsTheCount(void) {
    VPVirtIOSoundLatencyTracker tracker = defaultTracker();
    CHECK(!VPVirtIOSoundLatencyTrackerAddWindow(&tracker, 5));
    CHECK(!VPVirtIOSoundLatencyTrackerAddWindow(&tracker, 1));
    CHECK(!VPVirtIOSoundLatencyTrackerAddWindow(&tracker, 5));
    CHECK(tracker.periods == 3);
    CHECK(VPVirtIOSoundLatencyTrackerAddWindow(&tracker, 5));
    CHECK(tracker.periods == 6);
}

static void testPeriods(void) {
    CHECK(VPVirtIOSoundLatencyPeriods(0, 32768) == 0);
    CHECK(VPVirtIOSoundLatencyPeriods(32768, 32768) == 1);
    CHECK(VPVirtIOSoundLatencyPeriods(32769, 32768) == 2);
    CHECK(VPVirtIOSoundLatencyPeriods(5 * 32768, 32768) == 5);
    CHECK(VPVirtIOSoundLatencyPeriods(100, 0) == 0);
}

static void testFrames(void) {
    // Today's figure: lead 2 + 1 periods of 4096 frames, nothing from the host.
    CHECK(VPVirtIOSoundLatencyFrames(3 * 4096, 48000, 48000, 0) == 12288);
    // The same queue reported at 44100 is fewer frames of the same length.
    CHECK(VPVirtIOSoundLatencyFrames(12288, 48000, 44100, 0) == 11290);
    // The built-in speakers add about 14 ms, AirPods about 150 ms.
    CHECK(VPVirtIOSoundLatencyFrames(12288, 48000, 48000, 0.0145) == 12984);
    CHECK(VPVirtIOSoundLatencyFrames(6 * 4096, 48000, 48000, 0.150) == 31776);
    // Bad host values count as nothing, or as the most allowed.
    CHECK(VPVirtIOSoundLatencyFrames(12288, 48000, 48000, -1) == 12288);
    CHECK(VPVirtIOSoundLatencyFrames(12288, 48000, 48000, NAN) == 12288);
    CHECK(VPVirtIOSoundLatencyFrames(12288, 48000, 48000, 30) == 12288 + 48000);
    // No rate yet: the queue as it is.
    CHECK(VPVirtIOSoundLatencyFrames(12288, 0, 48000, 0.1) == 12288);
}

int main(void) {
    testBuiltInStaysAtTheFloor();
    testRisesAfterTwoWindowsToTheLesser();
    testSingleBurstIsIgnored();
    testFallsSlowly();
    testOppositeWindowResetsTheCount();
    testPeriods();
    testFrames();
    if (failures) {
        fprintf(stderr, "VirtIOSoundLatencyTests: %d failure(s)\n", failures);
        return 1;
    }
    printf("VirtIOSoundLatencyTests: all passed\n");
    return 0;
}
