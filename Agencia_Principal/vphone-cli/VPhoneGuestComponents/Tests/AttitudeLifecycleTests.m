#import "VPhoneAttitudeMotionManager.h"
#import "VPhoneAttitudeState.h"
#include "../Shared/AttitudeProcess.h"
#include <assert.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <notify.h>
#include <stdatomic.h>
#include <unistd.h>

// A sensorless manager records native entry points. The real macOS runtime
// tolerates stop-before-start; the guest Core Motion runtime can crash there.
static atomic_uint starts, stops;
@interface VPhoneTestMotionManager : NSObject <VPhoneAttitudeMotionManager>
@property (nonatomic) NSTimeInterval deviceMotionUpdateInterval;
@end
@implementation VPhoneTestMotionManager
+ (CMAttitudeReferenceFrame)availableAttitudeReferenceFrames { return 0; }
- (BOOL)isDeviceMotionAvailable { return NO; }
- (BOOL)isDeviceMotionActive { return NO; }
- (CMDeviceMotion *)deviceMotion { return nil; }
- (CMAttitudeReferenceFrame)attitudeReferenceFrame { return CMAttitudeReferenceFrameXArbitraryZVertical; }
- (void)startDeviceMotionUpdates { starts++; }
- (void)startDeviceMotionUpdatesUsingReferenceFrame:(CMAttitudeReferenceFrame)frame { [self startDeviceMotionUpdates]; }
- (void)startDeviceMotionUpdatesToQueue:(NSOperationQueue *)queue withHandler:(CMDeviceMotionHandler)handler { [self startDeviceMotionUpdates]; }
- (void)startDeviceMotionUpdatesUsingReferenceFrame:(CMAttitudeReferenceFrame)frame toQueue:(NSOperationQueue *)queue withHandler:(CMDeviceMotionHandler)handler { [self startDeviceMotionUpdates]; }
- (void)stopDeviceMotionUpdates { stops++; }
@end

static void publish(int token, BOOL enabled, VPhoneTestMotionManager *manager) {
    assert(notify_set_state(token, VPhoneAttitudePack((VPhoneAttitudeState){enabled, 0, 0, 0})) == NOTIFY_STATUS_OK);
    assert(notify_post(VP_ATTITUDE_NOTIFICATION) == NOTIFY_STATUS_OK);
    for (int i = 0; i < 200; i++) {
        if (manager.deviceMotionAvailable == enabled) return;
        usleep(5000);
    }
    assert(!"Timed out waiting for attitude configuration");
}

int main(void) {
    @autoreleasepool {
        VPhoneTestMotionManager *manager = [VPhoneTestMotionManager new];
        char path[PATH_MAX];
        uint32_t length = sizeof(path);
        assert(_NSGetExecutablePath(path, &length) == 0);
        if (!vpAttitudeAllowsProcess(path)) {
            // Run this executable from a system-UI-shaped path as well: the
            // dylib must leave native entry points intact before main runs.
            [manager stopDeviceMotionUpdates];
            assert(stops == 1);
            assert(!manager.deviceMotionAvailable);
            assert([VPhoneTestMotionManager availableAttitudeReferenceFrames] == 0);
            puts("System UI process leaves attitude hooks uninstalled");
            return 0;
        }
        int token;
        assert(notify_register_check(VP_ATTITUDE_NOTIFICATION, &token) == NOTIFY_STATUS_OK);
        publish(token, YES, manager);
        [manager stopDeviceMotionUpdates];
        assert(stops == 0); // No native subscription exists yet.
        [manager startDeviceMotionUpdates];
        [manager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryZVertical];
        [manager stopDeviceMotionUpdates];
        [manager stopDeviceMotionUpdates];
        assert(starts == 0 && stops == 0); // Simulation never touches native stop.

        // Unsupported frames retain native forwarding, including reentrant starts.
        [manager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXMagneticNorthZVertical];
        assert(starts == 1 && stops == 0);
        [manager stopDeviceMotionUpdates];
        [manager stopDeviceMotionUpdates];
        assert(stops == 1);

        // Switching a retained subscription stops native once, then stays simulated.
        publish(token, NO, manager);
        [manager startDeviceMotionUpdates];
        assert(starts == 2 && stops == 1);
        publish(token, YES, manager);
        for (int i = 0; i < 200 && !manager.deviceMotion; i++) usleep(5000);
        assert(manager.deviceMotion && stops == 2);
        [manager stopDeviceMotionUpdates];
        assert(stops == 2);
        publish(token, NO, manager);
        notify_cancel(token);
        puts("Sensorless native start/stop lifecycle tests passed");
    }
    return 0;
}
