#import "VPhoneGyroscopeHID.h"
#import "VPhoneGyroscopeState.h"
#include <dlfcn.h>
#include <mach/mach_time.h>
#include <notify.h>
#include <unistd.h>

// MARK: - HID provider in backboardd

@interface VPhoneGyroscopeProvider : NSObject
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) dispatch_source_t timer;
@property (nonatomic, strong) dispatch_source_t heartbeat;
@property (nonatomic, strong) id<VPhoneGyroscopeHIDService> service;
@property (nonatomic) Class<VPhoneGyroscopeHIDEvent> eventClass;
@property (nonatomic, strong) NSMutableDictionary *properties;
@property (nonatomic) VPhoneGyroscopeState state;
@property (nonatomic) BOOL enumerated;
@property (nonatomic) BOOL cancelling;
@property (nonatomic) uint32_t sequence;
@property (nonatomic) uint64_t interval;
@property (nonatomic) uint64_t dispatched;
@property (nonatomic) uint64_t failures;
@property (nonatomic) int notificationToken;
@property (nonatomic, copy) NSString *lastError;
- (void)start;
@end

@implementation VPhoneGyroscopeProvider

- (void)publishStatus {
    NSDictionary *status = @{
        @"enumerated": @(self.enumerated), @"service_id": @(self.service.serviceID),
        @"pid": @(getpid()), @"updated_at": @([NSDate date].timeIntervalSince1970),
        @"report_interval_us": @(self.interval), @"dispatched": @(self.dispatched),
        @"dispatch_failures": @(self.failures), @"error": self.lastError ?: @"",
        @"configuration": VPhoneGyroscopeEncode(self.state),
    };
    CFPreferencesSetValue(CFSTR(VP_GYRO_STATUS), (__bridge CFDictionaryRef)status,
                          CFSTR(VP_GYRO_DOMAIN), CFSTR("mobile"), kCFPreferencesAnyHost);
    CFPreferencesSynchronize(CFSTR(VP_GYRO_DOMAIN), CFSTR("mobile"), kCFPreferencesAnyHost);
}

- (void)readConfiguration {
    CFPreferencesSynchronize(CFSTR(VP_GYRO_DOMAIN), CFSTR("mobile"), kCFPreferencesAnyHost);
    id value = CFBridgingRelease(CFPreferencesCopyValue(CFSTR(VP_GYRO_CONFIGURATION),
                                  CFSTR(VP_GYRO_DOMAIN), CFSTR("mobile"), kCFPreferencesAnyHost));
    VPhoneGyroscopeState state;
    VPhoneGyroscopeDecode(value, &state);
    self.state = state;
    [self publishStatus];
}

- (void)updateTimer {
    uint64_t period = self.enumerated && self.interval ? self.interval * NSEC_PER_USEC : DISPATCH_TIME_FOREVER;
    dispatch_source_set_timer(self.timer, period == DISPATCH_TIME_FOREVER ? DISPATCH_TIME_FOREVER : DISPATCH_TIME_NOW,
                              period, NSEC_PER_MSEC);
    // The status is republished every two seconds only while samples flow,
    // to keep its dispatch counts current. Otherwise it changes only at the
    // transitions, which publish it themselves, and vphoned judges the
    // provider by its pid. An unconditional heartbeat had backboardd rewrite
    // the preferences domain through cfprefsd every two seconds for the
    // guest's whole life.
    if (self.heartbeat) {
        BOOL flowing = period != DISPATCH_TIME_FOREVER;
        dispatch_source_set_timer(self.heartbeat,
                                  flowing ? dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC) : DISPATCH_TIME_FOREVER,
                                  2 * NSEC_PER_SEC, 100 * NSEC_PER_MSEC);
    }
}

- (id)sample {
    VPhoneGyroscopeState state = self.state;
    // Clearing simulation gives the stationary sensor's zero rate. The HID
    // service stays present, so an already running client's subscription is
    // preserved and the next set does not require reopening CMMotionManager.
    id event = [self.eventClass gyroEvent:mach_absolute_time()
                                     x:state.enabled ? state.x : 0
                                     y:state.enabled ? state.y : 0
                                     z:state.enabled ? state.z : 0 options:0];
    if (event)
        [(id<VPhoneGyroscopeHIDEvent>)event setGyroSequence:self.sequence++];
    return event;
}

- (void)createService {
    self.enumerated = NO;
    self.cancelling = NO;
    self.interval = 0;
    self.properties[@"ReportInterval"] = @0;
    self.service = (id<VPhoneGyroscopeHIDService>)[NSClassFromString(@"HIDVirtualEventService") new];
    if (!self.service) {
        self.lastError = @"HIDVirtualEventService creation failed";
        [self publishStatus];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), self.queue, ^{ [self createService]; });
        return;
    }
    self.service.delegate = self;
    [self.service setDispatchQueue:self.queue];
    __weak VPhoneGyroscopeProvider *weakSelf = self;
    [self.service setCancelHandler:^{
        VPhoneGyroscopeProvider *provider = weakSelf;
        if (!provider)
            return;
        provider.service = nil;
        // A reset invalidates the old service. Cancel completely before
        // releasing it, then register a new one with the restarted HID server.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), provider.queue,
                       ^{ [provider createService]; });
    }];
    [self.service activate];
}

- (void)start {
    void *hid = dlopen("/System/Library/PrivateFrameworks/HID.framework/HID", RTLD_NOW | RTLD_LOCAL);
    self.eventClass = (Class<VPhoneGyroscopeHIDEvent>)NSClassFromString(@"HIDEvent");
    Class serviceClass = NSClassFromString(@"HIDVirtualEventService");
    if (!hid || !serviceClass ||
        ![self.eventClass respondsToSelector:@selector(gyroEvent:x:y:z:options:)] ||
        ![(Class)self.eventClass instancesRespondToSelector:@selector(setGyroSequence:)] ||
        ![serviceClass instancesRespondToSelector:@selector(dispatchEvent:)]) {
        self.lastError = @"Required HID virtual-service API unavailable";
        NSLog(@"[vphone-gyro] %@", self.lastError);
        [self publishStatus];
        return;
    }
    self.properties = [@{
        @"PrimaryUsagePage": @0xff00, @"PrimaryUsage": @9,
        @"DeviceUsagePairs": @[@{@"DeviceUsagePage": @0xff00, @"DeviceUsage": @9}],
        @"Product": @"VPhone 3D Gyroscope", @"Manufacturer": @"vphone",
        @"Transport": @"Virtual", @"Built-In": @YES, @"IMULocationID": @0,
        @"ReportInterval": @0, @"BatchInterval": @0,
        // Aggregate subscriptions before forwarding the requested interval to
        // this delegate, so one client's stop cannot stop other subscribers.
        @"HIDDefaultSensorControlOptions": @7, @"SensorPropertySupported": @3,
    } mutableCopy];
    [self readConfiguration];
    int status = notify_register_dispatch(VP_GYRO_NOTIFICATION, &_notificationToken, self.queue,
                                          ^(int token) { [self readConfiguration]; });
    if (status != NOTIFY_STATUS_OK) {
        self.lastError = @"Gyroscope configuration notification registration failed";
        [self publishStatus];
        return;
    }
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);
    dispatch_source_set_event_handler(self.timer, ^{
        @autoreleasepool {
            id event = [self sample];
            if (event && [self.service dispatchEvent:event]) {
                self.dispatched++;
            } else {
                self.failures++;
                self.lastError = @"HID event dispatch failed";
            }
        }
    });
    self.heartbeat = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);
    dispatch_source_set_event_handler(self.heartbeat, ^{ [self publishStatus]; });
    [self updateTimer];
    dispatch_resume(self.timer);
    dispatch_resume(self.heartbeat);
    [self createService];
}

// MARK: - HIDVirtualEventServiceDelegate selectors

- (id)propertyForKey:(NSString *)key forService:(id)service {
    return self.properties[key];
}

- (BOOL)setProperty:(id)value forKey:(NSString *)key forService:(id)service {
    if ([key isEqualToString:@"ReportInterval"]) {
        self.interval = VPhoneGyroscopeInterval(value);
        self.properties[key] = @(self.interval);
        [self updateTimer];
        [self publishStatus];
        return YES;
    }
    if ([key isEqualToString:@"BatchInterval"])
        return YES; // No FIFO: samples are delivered as they are made.
    return NO;
}

- (id)copyEventMatching:(NSDictionary *)matching forService:(id)service {
    NSNumber *type = matching[@"EventType"];
    return self.enumerated && (!type || type.unsignedIntValue == 0x14) ? [self sample] : nil;
}

- (BOOL)setOutputEvent:(id)event forService:(id)service {
    return NO;
}

- (void)notification:(NSInteger)type withProperty:(NSDictionary *)property forService:(id)service {
    if (service != self.service)
        return;
    if (type == 10) { // HIDVirtualServiceNotificationTypeEnumerated
        self.enumerated = YES;
        self.lastError = nil;
        NSLog(@"[vphone-gyro] HID service enumerated: %llu", self.service.serviceID);
    } else if (type == 11 && !self.cancelling) { // Terminated or reset
        self.enumerated = NO;
        self.cancelling = YES;
        self.lastError = @"HID service terminated; waiting to register again";
        [self.service cancel];
    }
    [self updateTimer];
    [self publishStatus];
}
@end

__attribute__((constructor)) static void VPhoneGyroscopeStart(void) {
    // SystemHook loads this only into backboardd, the mobile user's HID host.
    // Starting asynchronously avoids synchronously calling the HID server
    // while its daemon is still running image constructors.
    if (strcmp(getprogname(), "backboardd") != 0)
        return;
    static VPhoneGyroscopeProvider *provider;
    provider = [VPhoneGyroscopeProvider new];
    provider.queue = dispatch_queue_create("com.vphone.motion.gyroscope", DISPATCH_QUEUE_SERIAL);
    dispatch_async(provider.queue, ^{ [provider start]; });
}
