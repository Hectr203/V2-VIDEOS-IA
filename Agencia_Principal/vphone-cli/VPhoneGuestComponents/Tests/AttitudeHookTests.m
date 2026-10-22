#import "VPhoneAttitudeSample.h"
#import "VPhoneAttitudeMotionManager.h"
#include <assert.h>
#include <notify.h>
#include <unistd.h>

static int token;
static void publish(VPhoneAttitudeState state) {
    assert(notify_set_state(token, VPhoneAttitudePack(state)) == NOTIFY_STATUS_OK);
    assert(notify_post(VP_ATTITUDE_NOTIFICATION) == NOTIFY_STATUS_OK);
}
static void waitFor(BOOL (^condition)(void)) {
    for (int i = 0; i < 200; i++) {
        if (condition()) return;
        usleep(5000);
    }
    assert(!"Timed out waiting for the attitude hook");
}
static void closeTo(double actual, double expected) { assert(fabs(actual - expected) < 1e-8); }

int main(void) {
    @autoreleasepool {
        assert(notify_register_check(VP_ATTITUDE_NOTIFICATION, &token) == NOTIFY_STATUS_OK);
        Class<VPhoneAttitudeMotionManager> managerClass = (Class<VPhoneAttitudeMotionManager>)NSClassFromString(@"CMMotionManager");
        assert(managerClass);
        id<VPhoneAttitudeMotionManager> polling = [(Class)managerClass new];
        BOOL nativeAvailable = polling.deviceMotionAvailable;
        publish((VPhoneAttitudeState){YES, 30, -20, 45});
        waitFor(^BOOL { return polling.deviceMotionAvailable; });
        assert([managerClass availableAttitudeReferenceFrames] & CMAttitudeReferenceFrameXArbitraryZVertical);
        [polling startDeviceMotionUpdates];
        assert(polling.deviceMotionActive);
        assert(polling.attitudeReferenceFrame == CMAttitudeReferenceFrameXArbitraryZVertical);
        waitFor(^BOOL { return polling.deviceMotion != nil; });
        CMDeviceMotion *old = polling.deviceMotion;
        closeTo(old.attitude.roll, M_PI/6);
        closeTo(old.attitude.pitch, -M_PI/9);

        id<VPhoneAttitudeMotionManager> callbacks = [(Class)managerClass new];
        callbacks.deviceMotionUpdateInterval = 0.01;
        NSOperationQueue *queue = [NSOperationQueue new];
        queue.maxConcurrentOperationCount = 1;
        dispatch_semaphore_t received = dispatch_semaphore_create(0);
        __block NSTimeInterval timestamp = 0;
        [callbacks startDeviceMotionUpdatesToQueue:queue withHandler:^(CMDeviceMotion *sample, NSError *error) {
            assert(!error && sample.timestamp >= timestamp);
            timestamp = sample.timestamp;
            dispatch_semaphore_signal(received);
        }];
        assert(dispatch_semaphore_wait(received, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)) == 0);
        publish((VPhoneAttitudeState){YES, -60, 10, -90});
        waitFor(^BOOL { return fabs(polling.deviceMotion.attitude.roll + M_PI/3) < 1e-8; });
        closeTo(old.attitude.roll, M_PI/6); // Delivered samples are snapshots.
        [callbacks stopDeviceMotionUpdates];
        [queue waitUntilAllOperationsAreFinished];
        assert(!callbacks.deviceMotionActive && callbacks.deviceMotion == nil);

        // Bound delivery backlog and discard queued callbacks after a stop.
        queue.suspended = YES;
        __block int calls = 0;
        [callbacks startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryZVertical
            toQueue:queue withHandler:^(CMDeviceMotion *sample, NSError *error) { calls++; }];
        usleep(80000);
        assert(queue.operationCount == 1);
        [callbacks stopDeviceMotionUpdates];
        queue.suspended = NO;
        [queue waitUntilAllOperationsAreFinished];
        assert(calls == 0);

        // Exercise explicit polling and toggling an existing subscription.
        [polling startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryZVertical];
        publish((VPhoneAttitudeState){NO, -60, 10, -90});
        waitFor(^BOOL { return polling.deviceMotionAvailable == nativeAvailable && ![polling.deviceMotion isKindOfClass:VPhoneAttitudeSample.class]; });
        publish((VPhoneAttitudeState){YES, 0, 0, 0});
        waitFor(^BOOL { return [polling.deviceMotion isKindOfClass:VPhoneAttitudeSample.class]; });
        closeTo(polling.deviceMotion.gravity.z, -1);
        [polling stopDeviceMotionUpdates];
        publish((VPhoneAttitudeState){0});
        notify_cancel(token);
        puts("Core Motion polling, callback, live toggle, snapshot and bounded backlog tests passed");
    }
    return 0;
}
