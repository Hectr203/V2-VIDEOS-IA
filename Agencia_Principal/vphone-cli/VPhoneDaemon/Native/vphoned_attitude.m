#import "Include/VphonedNative.h"
#import "../../VPhoneGuestComponents/Attitude/VPhoneAttitudeState.h"
#include <notify.h>
#include <unistd.h>

static VPhoneAttitudeState VPhoneAttitudeRead(void) {
    CFPreferencesSynchronize(CFSTR(VP_ATTITUDE_DOMAIN), CFSTR("mobile"), kCFPreferencesAnyHost);
    id value = CFBridgingRelease(CFPreferencesCopyValue(CFSTR(VP_ATTITUDE_CONFIGURATION),
        CFSTR(VP_ATTITUDE_DOMAIN), CFSTR("mobile"), kCFPreferencesAnyHost));
    VPhoneAttitudeState state;
    VPhoneAttitudeDecode(value, &state);
    return state;
}

static BOOL VPhoneAttitudePublish(VPhoneAttitudeState state) {
    static int token, registration = NOTIFY_STATUS_FAILED;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ registration = notify_register_check(VP_ATTITUDE_NOTIFICATION, &token); });
    return registration == NOTIFY_STATUS_OK &&
           notify_set_state(token, VPhoneAttitudePack(state)) == NOTIFY_STATUS_OK &&
           notify_post(VP_ATTITUDE_NOTIFICATION) == NOTIFY_STATUS_OK;
}

NSDictionary *vp_attitude_get(void) {
    VPhoneAttitudeState state = VPhoneAttitudeRead();
    VPhoneAttitudePublish(state);
    NSMutableDictionary *result = [VPhoneAttitudeEncode(state) mutableCopy];
    result[@"units"] = @"degrees";
    result[@"reference_frame"] = @"xArbitraryZVertical";
    result[@"provider_installed"] = @(access("/usr/lib/libvphoneattitude.dylib", R_OK) == 0);
    return result;
}

BOOL vp_attitude_set(double roll, double pitch, double yaw, bool enabled) {
    VPhoneAttitudeState state = {enabled, roll, pitch, yaw}, checked;
    NSDictionary *value = VPhoneAttitudeEncode(state);
    if (!VPhoneAttitudeDecode(value, &checked)) return NO;
    CFPreferencesSetValue(CFSTR(VP_ATTITUDE_CONFIGURATION), (__bridge CFDictionaryRef)value,
                          CFSTR(VP_ATTITUDE_DOMAIN), CFSTR("mobile"), kCFPreferencesAnyHost);
    return CFPreferencesSynchronize(CFSTR(VP_ATTITUDE_DOMAIN), CFSTR("mobile"), kCFPreferencesAnyHost) &&
           VPhoneAttitudePublish(state);
}

// Re-seed notifyd after boot/daemon restart before any host editor is opened.
__attribute__((constructor)) static void VPhoneAttitudeInitialize(void) {
    @autoreleasepool { VPhoneAttitudePublish(VPhoneAttitudeRead()); }
}
