// Core Motion's own methods wait for its MotionThread, and the MotionThread
// calls back into public CMMotionManager getters. SpringBoard on iOS 26.6.2
// deadlocked this way on its first Home Screen: `_UIMotionEffectCoreMotionEventProvider`
// set the update interval, the hook held the session lock around the native
// setter, and the MotionThread's `isDeviceMotionActive` waited for that lock.
//
// This file must be linked before the hook's sources: its constructor puts
// stand-ins for the native methods in place first, so the hook keeps them as
// the "actual implementations" and calls them as it would call Core Motion.
#import "VPhoneAttitudeSample.h"
#import "VPhoneAttitudeMotionManager.h"
#import <objc/runtime.h>
#include <assert.h>
#include <notify.h>
#include <unistd.h>

static dispatch_queue_t motionThread;
static int nativeCalls;
static void (*realInterval)(id, SEL, NSTimeInterval);
static void (*realStart)(id, SEL, CMAttitudeReferenceFrame);
static void (*realStop)(id, SEL);

// What the MotionThread does while a caller waits for it: read the public
// getters, which the hook replaces. dispatch_sync would run the block on the
// caller's thread, so the wait goes through a semaphore as the real one does.
static void waitForMotionThread(id<VPhoneAttitudeMotionManager> manager) {
    nativeCalls++;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    dispatch_async(motionThread, ^{
        (void)manager.deviceMotionActive;
        (void)manager.deviceMotion;
        (void)manager.attitudeReferenceFrame;
        (void)manager.deviceMotionAvailable;
        dispatch_semaphore_signal(done);
    });
    dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
}
static void nativeInterval(id manager, SEL selector, NSTimeInterval value) {
    waitForMotionThread(manager);
    realInterval(manager, selector, value);
}
static void nativeStart(id manager, SEL selector, CMAttitudeReferenceFrame frame) {
    waitForMotionThread(manager);
    realStart(manager, selector, frame);
}
static void nativeStop(id manager, SEL selector) {
    waitForMotionThread(manager);
    realStop(manager, selector);
}

__attribute__((constructor)) static void installNativeStandIns(void) {
    motionThread = dispatch_queue_create("test.CoreMotion.MotionThread", DISPATCH_QUEUE_SERIAL);
    Class cls = NSClassFromString(@"CMMotionManager");
    assert(cls);
    realInterval = (__typeof__(realInterval))method_setImplementation(
        class_getInstanceMethod(cls, @selector(setDeviceMotionUpdateInterval:)), (IMP)nativeInterval);
    realStart = (__typeof__(realStart))method_setImplementation(
        class_getInstanceMethod(cls, @selector(startDeviceMotionUpdatesUsingReferenceFrame:)), (IMP)nativeStart);
    realStop = (__typeof__(realStop))method_setImplementation(
        class_getInstanceMethod(cls, @selector(stopDeviceMotionUpdates)), (IMP)nativeStop);
}

static int token;
static void publish(VPhoneAttitudeState state) {
    assert(notify_set_state(token, VPhoneAttitudePack(state)) == NOTIFY_STATUS_OK);
    assert(notify_post(VP_ATTITUDE_NOTIFICATION) == NOTIFY_STATUS_OK);
}

// Runs `body` off the main thread and fails instead of hanging.
static void finishes(const char *what, void (^body)(void)) {
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        body();
        dispatch_semaphore_signal(done);
    });
    if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)) != 0) {
        fprintf(stderr, "deadlock: %s did not return while Core Motion waited for its MotionThread\n", what);
        _exit(1);
    }
}

int main(void) {
    @autoreleasepool {
        assert(notify_register_check(VP_ATTITUDE_NOTIFICATION, &token) == NOTIFY_STATUS_OK);
        Class managerClass = NSClassFromString(@"CMMotionManager");
        id<VPhoneAttitudeMotionManager> manager = [managerClass new];

        // Native path: the simulation is off, so every call reaches Core Motion.
        publish((VPhoneAttitudeState){0});
        finishes("setDeviceMotionUpdateInterval:", ^{ manager.deviceMotionUpdateInterval = 0.02; });
        finishes("startDeviceMotionUpdatesUsingReferenceFrame:", ^{
            [manager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryZVertical];
        });
        finishes("setDeviceMotionUpdateInterval: while running", ^{ manager.deviceMotionUpdateInterval = 0.05; });

        // Simulated path: turning the simulation on stops the native updates
        // from the notification queue while the session is locked.
        publish((VPhoneAttitudeState){YES, 10, 20, 30});
        for (int i = 0; i < 200 && ![manager.deviceMotion isKindOfClass:VPhoneAttitudeSample.class]; i++) usleep(5000);
        assert([manager.deviceMotion isKindOfClass:VPhoneAttitudeSample.class]);
        finishes("setDeviceMotionUpdateInterval: while simulating", ^{ manager.deviceMotionUpdateInterval = 0.01; });
        publish((VPhoneAttitudeState){0});
        for (int i = 0; i < 200 && [manager.deviceMotion isKindOfClass:VPhoneAttitudeSample.class]; i++) usleep(5000);
        finishes("stopDeviceMotionUpdates", ^{ [manager stopDeviceMotionUpdates]; });

        assert(nativeCalls >= 4); // The hook called the stand-ins, not Core Motion directly.
        notify_cancel(token);
        puts("Core Motion calls that wait for the MotionThread do not deadlock with the attitude hook");
    }
    return 0;
}
