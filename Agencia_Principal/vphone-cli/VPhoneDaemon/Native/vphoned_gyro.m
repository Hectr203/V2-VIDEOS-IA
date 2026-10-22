#import "Include/VphonedNative.h"
#import "../../VPhoneGuestComponents/Gyroscope/VPhoneGyroscopeState.h"
#include <errno.h>
#include <notify.h>
#include <signal.h>

static id VPhoneGyroscopeRead(CFStringRef key) {
    return CFBridgingRelease(CFPreferencesCopyValue(key, CFSTR(VP_GYRO_DOMAIN), CFSTR("mobile"),
                                                  kCFPreferencesAnyHost));
}

NSDictionary *vp_gyro_get(void) {
    CFPreferencesSynchronize(CFSTR(VP_GYRO_DOMAIN), CFSTR("mobile"), kCFPreferencesAnyHost);
    VPhoneGyroscopeState state;
    VPhoneGyroscopeDecode(VPhoneGyroscopeRead(CFSTR(VP_GYRO_CONFIGURATION)), &state);
    NSMutableDictionary *result = [VPhoneGyroscopeEncode(state) mutableCopy];
    result[@"units"] = @"rad/s";
    id status = VPhoneGyroscopeRead(CFSTR(VP_GYRO_STATUS));
    if ([status isKindOfClass:NSDictionary.class] &&
        [status[@"updated_at"] isKindOfClass:NSNumber.class] &&
        [status[@"enumerated"] isKindOfClass:NSNumber.class]) {
        result[@"provider"] = status;
        double age = [NSDate date].timeIntervalSince1970 - [status[@"updated_at"] doubleValue];
        // The provider republishes every two seconds only while it dispatches
        // samples; idle, its status is as old as the last transition, and the
        // backboardd that wrote it must still be running instead.
        BOOL dispatching = [status[@"report_interval_us"] isKindOfClass:NSNumber.class] &&
                           [status[@"report_interval_us"] unsignedLongLongValue] > 0;
        BOOL alive = NO;
        if ([status[@"pid"] isKindOfClass:NSNumber.class]) {
            pid_t pid = [status[@"pid"] intValue];
            alive = pid > 1 && (kill(pid, 0) == 0 || errno == EPERM);
        }
        BOOL fresh = age >= 0 && age < 10;
        result[@"provider_running"] = @([status[@"enumerated"] boolValue] && alive && (fresh || !dispatching));
    } else {
        result[@"provider"] = NSNull.null;
        result[@"provider_running"] = @NO;
    }
    return result;
}

BOOL vp_gyro_set(double x, double y, double z, bool enabled) {
    VPhoneGyroscopeState state = {enabled, x, y, z}, checked;
    NSDictionary *value = VPhoneGyroscopeEncode(state);
    if (!VPhoneGyroscopeDecode(value, &checked))
        return NO;
    CFPreferencesSetValue(CFSTR(VP_GYRO_CONFIGURATION), (__bridge CFDictionaryRef)value,
                          CFSTR(VP_GYRO_DOMAIN), CFSTR("mobile"), kCFPreferencesAnyHost);
    if (!CFPreferencesSynchronize(CFSTR(VP_GYRO_DOMAIN), CFSTR("mobile"), kCFPreferencesAnyHost))
        return NO;
    return notify_post(VP_GYRO_NOTIFICATION) == NOTIFY_STATUS_OK;
}
