#pragma once
#import <Foundation/Foundation.h>
#include <math.h>

// One dictionary per update: readers never combine axes from different RPCs.
#define VP_GYRO_DOMAIN "com.apple.backboardd"
#define VP_GYRO_CONFIGURATION "VPhoneGyroscopeConfiguration"
#define VP_GYRO_STATUS "VPhoneGyroscopeStatus"
#define VP_GYRO_NOTIFICATION "com.vphone.motion.gyroscope.changed"

typedef struct {
    BOOL enabled;
    double x, y, z; // CoreMotion rotation rate, radians per second.
} VPhoneGyroscopeState;

// Reject malformed persisted state, booleans masquerading as axes, and rates
// outside the HID event's signed 16.16 range. No partial-axis updates.
static inline BOOL VPhoneGyroscopeNumber(id value) {
    return [value isKindOfClass:NSNumber.class] &&
           CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID();
}

static inline BOOL VPhoneGyroscopeDecode(id value, VPhoneGyroscopeState *state) {
    *state = (VPhoneGyroscopeState){0};
    if (![value isKindOfClass:NSDictionary.class])
        return NO;
    id enabled = value[@"enabled"];
    if (![enabled isKindOfClass:NSNumber.class] ||
        CFGetTypeID((__bridge CFTypeRef)enabled) != CFBooleanGetTypeID())
        return NO;
    double axes[3];
    NSArray *keys = @[@"x", @"y", @"z"];
    for (NSUInteger index = 0; index < 3; index++) {
        id axis = value[keys[index]];
        if (!VPhoneGyroscopeNumber(axis))
            return NO;
        axes[index] = [axis doubleValue];
        if (!isfinite(axes[index]) || fabs(axes[index]) > 1000)
            return NO;
    }
    *state = (VPhoneGyroscopeState){[enabled boolValue], axes[0], axes[1], axes[2]};
    return YES;
}

static inline NSDictionary *VPhoneGyroscopeEncode(VPhoneGyroscopeState state) {
    return @{@"enabled": @(state.enabled), @"x": @(state.x), @"y": @(state.y), @"z": @(state.z)};
}

// HID report interval, microseconds. Zero means there are no subscribers.
static inline uint64_t VPhoneGyroscopeInterval(id value) {
    if (!VPhoneGyroscopeNumber(value))
        return 0;
    double interval = [value doubleValue];
    if (!isfinite(interval) || interval <= 0)
        return 0;
    return (uint64_t)fmin(1000000, fmax(5000, interval));
}
