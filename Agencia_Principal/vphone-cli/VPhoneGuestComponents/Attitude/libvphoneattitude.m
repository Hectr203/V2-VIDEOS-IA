#import "VPhoneAttitudeSample.h"
#import "VPhoneAttitudeMotionManager.h"
#include "../Shared/AttitudeProcess.h"
#import <objc/runtime.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <notify.h>
#include <os/lock.h>

#ifndef VP_ATTITUDE_MANAGER_CLASS
#define VP_ATTITUDE_MANAGER_CLASS "CMMotionManager"
#endif

// MARK: - Shared configuration

static NSRecursiveLock *configurationLock;
static NSHashTable *sessions;
static VPhoneAttitudeState configuration;
static int notificationToken;
static char sessionKey;

static VPhoneAttitudeState VPhoneCurrentAttitude(void) {
    [configurationLock lock];
    VPhoneAttitudeState value = configuration;
    [configurationLock unlock];
    return value;
}

// Preserve the actual implementations, including calls they make to each other.
static void (*startPolling)(id, SEL);
static void (*startFramePolling)(id, SEL, CMAttitudeReferenceFrame);
static void (*startCallback)(id, SEL, NSOperationQueue *, CMDeviceMotionHandler);
static void (*startFrameCallback)(id, SEL, CMAttitudeReferenceFrame, NSOperationQueue *, CMDeviceMotionHandler);
static void (*stopUpdates)(id, SEL);
static void (*setInterval)(id, SEL, NSTimeInterval);
static BOOL (*isAvailable)(id, SEL);
static BOOL (*isActive)(id, SEL);
static CMDeviceMotion *(*getMotion)(id, SEL);
static CMAttitudeReferenceFrame (*getFrame)(id, SEL);
static CMAttitudeReferenceFrame (*availableFrames)(id, SEL);

@interface VPhoneAttitudeSession : NSObject
@property (nonatomic, weak) id<VPhoneAttitudeMotionManager> manager;
@property (nonatomic, strong) NSOperationQueue *deliveryQueue;
@property (nonatomic, copy) CMDeviceMotionHandler handler;
@property (nonatomic, strong) dispatch_source_t timer;
// Read without the session lock by the getters below; see "Lock order".
@property (atomic, strong) CMDeviceMotion *latest;
@property (atomic) CMAttitudeReferenceFrame frame;
@property (atomic) BOOL active;
@property (nonatomic) BOOL nativeActive;
@property (nonatomic) BOOL invokingNative;
@property (nonatomic) NSUInteger generation;
@property (nonatomic, strong) NSNumber *queuedGeneration;
- (void)refresh;
- (void)reschedule;
- (void)stop;
@end

@implementation VPhoneAttitudeSession
- (BOOL)simulating {
    return self.active && self.frame == CMAttitudeReferenceFrameXArbitraryZVertical && VPhoneCurrentAttitude().enabled;
}
- (void)reschedule {
    @synchronized (self) {
        double interval = self.manager.deviceMotionUpdateInterval;
        if (!isfinite(interval) || interval <= 0) interval = 1.0 / 60;
        uint64_t period = (uint64_t)(fmax(0.005, fmin(1, interval)) * NSEC_PER_SEC);
        if (self.timer) dispatch_source_set_timer(self.timer, DISPATCH_TIME_NOW, period, NSEC_PER_MSEC);
    }
}
- (void)tick {
    @synchronized (self) {
        if (![self simulating]) return;
        self.latest = [[VPhoneAttitudeSample alloc] initWithState:VPhoneCurrentAttitude()
            timestamp:NSProcessInfo.processInfo.systemUptime];
        if (!self.handler || self.queuedGeneration) return;
        NSUInteger generation = self.generation;
        self.queuedGeneration = @(generation);
        __weak VPhoneAttitudeSession *weakSelf = self;
        [self.deliveryQueue addOperationWithBlock:^{
            VPhoneAttitudeSession *session = weakSelf;
            // Recheck on the app's queue: stop/restart/disable invalidates
            // callbacks waiting behind a suspended or slow operation queue.
            CMDeviceMotionHandler handler;
            CMDeviceMotion *sample;
            @synchronized (session) {
                if (session.queuedGeneration.unsignedIntegerValue == generation) session.queuedGeneration = nil;
                if (session.generation != generation || ![session simulating]) return;
                handler = session.handler;
                sample = session.latest;
            }
            if (handler) handler(sample, nil);
        }];
    }
}
- (void)refresh {
    @synchronized (self) {
        id<VPhoneAttitudeMotionManager> manager = self.manager;
        if (!self.active || !manager) return;
        BOOL needsNative = ![self simulating];
        if (needsNative == self.nativeActive) return;
        self.generation++;
        self.queuedGeneration = nil;
        self.latest = nil;
        self.invokingNative = YES;
        if (needsNative) {
            if (self.handler) {
                NSUInteger generation = self.generation;
                __weak VPhoneAttitudeSession *weakSelf = self;
                startFrameCallback(manager, @selector(startDeviceMotionUpdatesUsingReferenceFrame:toQueue:withHandler:),
                    self.frame, self.deliveryQueue, ^(CMDeviceMotion *sample, NSError *error) {
                        VPhoneAttitudeSession *session = weakSelf;
                        CMDeviceMotionHandler handler;
                        @synchronized (session) {
                            if (!session.active || session.generation != generation || [session simulating]) return;
                            handler = session.handler;
                        }
                        if (handler) handler(sample, error);
                    });
            } else {
                startFramePolling(manager, @selector(startDeviceMotionUpdatesUsingReferenceFrame:), self.frame);
            }
        } else {
            stopUpdates(manager, @selector(stopDeviceMotionUpdates));
        }
        self.nativeActive = needsNative;
        self.invokingNative = NO;
    }
}
- (void)startWithFrame:(CMAttitudeReferenceFrame)frame queue:(NSOperationQueue *)queue handler:(CMDeviceMotionHandler)handler {
    @synchronized (self) {
        [self stop];
        self.frame = frame;
        self.deliveryQueue = queue;
        self.handler = handler;
        self.active = YES;
        // A timer also caches polling samples at the requested interval.
        self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
            dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0));
        __weak VPhoneAttitudeSession *weakSelf = self;
        dispatch_source_set_event_handler(self.timer, ^{ @autoreleasepool { [weakSelf tick]; } });
        [self reschedule];
        dispatch_resume(self.timer);
        [self refresh];
        [self tick];
    }
}
- (void)stop {
    @synchronized (self) {
        self.active = NO;
        self.generation++;
        self.queuedGeneration = nil;
        if (self.timer) dispatch_source_cancel(self.timer);
        self.timer = nil;
        self.latest = nil;
        self.handler = nil;
        self.deliveryQueue = nil;
        // Starting a simulated subscription also comes through stop. Calling
        // native stop before a native start can initialize sensorless guest
        // Core Motion and crash its motion thread (SpringBoard respring).
        if (self.nativeActive) {
            self.invokingNative = YES;
            stopUpdates(self.manager, @selector(stopDeviceMotionUpdates));
            self.invokingNative = NO;
        }
        self.nativeActive = NO;
    }
}
- (void)dealloc { if (_timer) dispatch_source_cancel(_timer); }
@end

// MARK: - Lock order
//
// Core Motion's own methods can wait for its MotionThread, and that thread
// calls the public getters (`isDeviceMotionActive`, `deviceMotion`, …) on the
// same manager. So no thread may wait for the session lock, or for the
// manager's own `@synchronized` lock, inside a hooked getter: a caller holding
// it while it runs a native method would wait for the MotionThread forever.
// On iOS 26.6.2 that froze SpringBoard's main thread when it built the Home
// Screen's parallax (`_UIMotionEffectCoreMotionEventProvider` sets the update
// interval). The getters read the atomic `active`, `frame` and `latest`
// without the session lock, the setter calls the native method before taking
// it, and the session is looked up under a private lock that is never held
// across a call out.

static os_unfair_lock sessionCreationLock = OS_UNFAIR_LOCK_INIT;

static VPhoneAttitudeSession *VPhoneSession(id<VPhoneAttitudeMotionManager> manager) {
    VPhoneAttitudeSession *session = objc_getAssociatedObject(manager, &sessionKey);
    if (session) return session;
    VPhoneAttitudeSession *created = [VPhoneAttitudeSession new];
    created.manager = manager;
    BOOL inserted = NO;
    os_unfair_lock_lock(&sessionCreationLock);
    session = objc_getAssociatedObject(manager, &sessionKey);
    if (!session) {
        objc_setAssociatedObject(manager, &sessionKey, created, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        session = created;
        inserted = YES;
    }
    os_unfair_lock_unlock(&sessionCreationLock);
    if (inserted) {
        [configurationLock lock];
        [sessions addObject:session];
        [configurationLock unlock];
    }
    return session;
}

// MARK: - CMMotionManager public entry points

static void VPhoneStart(id manager, SEL selector) {
    VPhoneAttitudeSession *session = VPhoneSession(manager);
    @synchronized (session) {
        if (session.invokingNative) { startPolling(manager, selector); return; }
        [session startWithFrame:CMAttitudeReferenceFrameXArbitraryZVertical queue:nil handler:nil];
    }
}
static void VPhoneStartFrame(id manager, SEL selector, CMAttitudeReferenceFrame frame) {
    VPhoneAttitudeSession *session = VPhoneSession(manager);
    @synchronized (session) {
        if (session.invokingNative) { startFramePolling(manager, selector, frame); return; }
        [session startWithFrame:frame queue:nil handler:nil];
    }
}
static void VPhoneStartCallback(id manager, SEL selector, NSOperationQueue *queue, CMDeviceMotionHandler handler) {
    VPhoneAttitudeSession *session = VPhoneSession(manager);
    @synchronized (session) {
        if (session.invokingNative) { startCallback(manager, selector, queue, handler); return; }
        [session startWithFrame:CMAttitudeReferenceFrameXArbitraryZVertical queue:queue handler:handler];
    }
}
static void VPhoneStartFrameCallback(id manager, SEL selector, CMAttitudeReferenceFrame frame,
                                     NSOperationQueue *queue, CMDeviceMotionHandler handler) {
    VPhoneAttitudeSession *session = VPhoneSession(manager);
    @synchronized (session) {
        if (session.invokingNative) { startFrameCallback(manager, selector, frame, queue, handler); return; }
        [session startWithFrame:frame queue:queue handler:handler];
    }
}
static void VPhoneStop(id manager, SEL selector) {
    VPhoneAttitudeSession *session = VPhoneSession(manager);
    @synchronized (session) {
        if (session.invokingNative) { stopUpdates(manager, selector); return; }
        [session stop];
    }
}
static void VPhoneInterval(id manager, SEL selector, NSTimeInterval value) {
    setInterval(manager, selector, value);
    [VPhoneSession(manager) reschedule];
}
static BOOL VPhoneAvailable(id manager, SEL selector) {
    return VPhoneCurrentAttitude().enabled || isAvailable(manager, selector);
}
// The getters take no lock that a caller of a native method may hold.
static BOOL VPhoneActive(id manager, SEL selector) {
    return [VPhoneSession(manager) simulating] || isActive(manager, selector);
}
static CMDeviceMotion *VPhoneMotion(id manager, SEL selector) {
    VPhoneAttitudeSession *session = VPhoneSession(manager);
    return [session simulating] ? session.latest : getMotion(manager, selector);
}
static CMAttitudeReferenceFrame VPhoneFrame(id manager, SEL selector) {
    VPhoneAttitudeSession *session = VPhoneSession(manager);
    return [session simulating] ? session.frame : getFrame(manager, selector);
}
static CMAttitudeReferenceFrame VPhoneFrames(id manager, SEL selector) {
    CMAttitudeReferenceFrame frames = availableFrames(manager, selector);
    return VPhoneCurrentAttitude().enabled ? frames | CMAttitudeReferenceFrameXArbitraryZVertical : frames;
}

static void VPhoneReadAttitude(void) {
    uint64_t state = 0;
    if (notify_get_state(notificationToken, &state) != NOTIFY_STATUS_OK) return;
    [configurationLock lock];
    configuration = VPhoneAttitudeUnpack(state);
    NSArray *live = sessions.allObjects;
    [configurationLock unlock];
    for (VPhoneAttitudeSession *session in live) { [session refresh]; [session tick]; }
}

__attribute__((constructor)) static void VPhoneAttitudeInstall(void) {
    @autoreleasepool {
        // Also enforce scope here: a live dylib update can reach a guest
        // still running the older SystemHook until its next reboot.
        char path[PATH_MAX];
        uint32_t length = sizeof(path);
        if (_NSGetExecutablePath(path, &length) != 0 || !vpAttitudeAllowsProcess(path)) return;
        configurationLock = [NSRecursiveLock new];
        sessions = [NSHashTable weakObjectsHashTable];
        dispatch_queue_t queue = dispatch_queue_create("com.vphone.motion.attitude", DISPATCH_QUEUE_SERIAL);
        if (notify_register_dispatch(VP_ATTITUDE_NOTIFICATION, &notificationToken, queue,
            ^(int token) { VPhoneReadAttitude(); }) != NOTIFY_STATUS_OK) return;
        VPhoneReadAttitude();
        Class cls = NSClassFromString(@VP_ATTITUDE_MANAGER_CLASS);
        // Validate the entire ABI before installing any part of the hook.
        SEL selectors[] = {@selector(startDeviceMotionUpdates), @selector(startDeviceMotionUpdatesUsingReferenceFrame:),
            @selector(startDeviceMotionUpdatesToQueue:withHandler:), @selector(startDeviceMotionUpdatesUsingReferenceFrame:toQueue:withHandler:),
            @selector(stopDeviceMotionUpdates), @selector(setDeviceMotionUpdateInterval:), @selector(isDeviceMotionAvailable),
            @selector(isDeviceMotionActive), @selector(deviceMotion), @selector(attitudeReferenceFrame)};
        for (NSUInteger i = 0; i < sizeof(selectors)/sizeof(*selectors); i++)
            if (!class_getInstanceMethod(cls, selectors[i])) return;
        Method frames = class_getClassMethod(cls, @selector(availableAttitudeReferenceFrames));
        if (!frames) return;
#define VP_HOOK(methodName, replacement, original) \
        original = (__typeof__(original))method_setImplementation(class_getInstanceMethod(cls, @selector(methodName)), (IMP)replacement)
        VP_HOOK(startDeviceMotionUpdates, VPhoneStart, startPolling);
        VP_HOOK(startDeviceMotionUpdatesUsingReferenceFrame:, VPhoneStartFrame, startFramePolling);
        VP_HOOK(startDeviceMotionUpdatesToQueue:withHandler:, VPhoneStartCallback, startCallback);
        VP_HOOK(startDeviceMotionUpdatesUsingReferenceFrame:toQueue:withHandler:, VPhoneStartFrameCallback, startFrameCallback);
        VP_HOOK(stopDeviceMotionUpdates, VPhoneStop, stopUpdates);
        VP_HOOK(setDeviceMotionUpdateInterval:, VPhoneInterval, setInterval);
        VP_HOOK(isDeviceMotionAvailable, VPhoneAvailable, isAvailable);
        VP_HOOK(isDeviceMotionActive, VPhoneActive, isActive);
        VP_HOOK(deviceMotion, VPhoneMotion, getMotion);
        VP_HOOK(attitudeReferenceFrame, VPhoneFrame, getFrame);
#undef VP_HOOK
        availableFrames = (__typeof__(availableFrames))method_setImplementation(frames, (IMP)VPhoneFrames);
    }
}
