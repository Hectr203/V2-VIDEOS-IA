#pragma once
#import <Foundation/Foundation.h>
#include <math.h>

#define VP_ATTITUDE_DOMAIN "com.apple.backboardd"
#define VP_ATTITUDE_CONFIGURATION "VPhoneAttitudeConfiguration"
#ifndef VP_ATTITUDE_NOTIFICATION
#define VP_ATTITUDE_NOTIFICATION "com.vphone.motion.attitude.changed"
#endif

typedef struct {
    BOOL enabled;
    double roll, pitch, yaw; // Degrees at the RPC boundary; Core Motion uses radians.
} VPhoneAttitudeState;

static inline BOOL VPhoneAttitudeDecode(id value, VPhoneAttitudeState *state) {
    *state = (VPhoneAttitudeState){0};
    if (![value isKindOfClass:NSDictionary.class]) return NO;
    id enabled = value[@"enabled"];
    if (![enabled isKindOfClass:NSNumber.class] ||
        CFGetTypeID((__bridge CFTypeRef)enabled) != CFBooleanGetTypeID()) return NO;
    double angles[3], limits[] = {180, 90, 180};
    NSArray *keys = @[@"roll", @"pitch", @"yaw"];
    for (NSUInteger i = 0; i < 3; i++) {
        id angle = value[keys[i]];
        if (![angle isKindOfClass:NSNumber.class] ||
            CFGetTypeID((__bridge CFTypeRef)angle) == CFBooleanGetTypeID()) return NO;
        angles[i] = [angle doubleValue];
        if (!isfinite(angles[i]) || fabs(angles[i]) > limits[i]) return NO;
    }
    *state = (VPhoneAttitudeState){[enabled boolValue], angles[0], angles[1], angles[2]};
    return YES;
}

static inline NSDictionary *VPhoneAttitudeEncode(VPhoneAttitudeState state) {
    return @{@"enabled": @(state.enabled), @"roll": @(state.roll),
             @"pitch": @(state.pitch), @"yaw": @(state.yaw)};
}

// One notify state holds the complete pose, including enabled. Millidegree
// quantization avoids cross-domain preferences reads by sandboxed apps.
static inline uint64_t VPhoneAttitudePack(VPhoneAttitudeState state) {
    uint64_t roll = (uint64_t)llround((state.roll + 180) * 1000);
    uint64_t pitch = (uint64_t)llround((state.pitch + 90) * 1000);
    uint64_t yaw = (uint64_t)llround((state.yaw + 180) * 1000);
    return (UINT64_C(1) << 63) | ((uint64_t)state.enabled << 56) | (yaw << 37) | (pitch << 19) | roll;
}

static inline VPhoneAttitudeState VPhoneAttitudeUnpack(uint64_t value) {
    if (!(value & (UINT64_C(1) << 63))) return (VPhoneAttitudeState){0};
    uint64_t r = value & 0x7ffff, p = (value >> 19) & 0x3ffff, y = (value >> 37) & 0x7ffff;
    if (r > 360000 || p > 180000 || y > 360000) return (VPhoneAttitudeState){0};
    return (VPhoneAttitudeState){(value >> 56) & 1, r / 1000.0 - 180,
                                p / 1000.0 - 90, y / 1000.0 - 180};
}
