#import "VPhoneGyroscopeState.h"
#import "VPhoneGyroscopeHID.h"
#include <assert.h>
#include <dlfcn.h>
#include <float.h>
#include <stdio.h>

int main(void) {
    @autoreleasepool {
        VPhoneGyroscopeState state;
        NSDictionary *sample = @{@"enabled": @YES, @"x": @1.25, @"y": @-2.5, @"z": @0.125};
        // The transport is a property list, including a real Boolean. Test
        // after serialization, as cfprefsd crosses a process boundary.
        NSData *wire = [NSPropertyListSerialization dataWithPropertyList:sample
                                     format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
        id decoded = [NSPropertyListSerialization propertyListWithData:wire options:0 format:nil error:nil];
        assert(VPhoneGyroscopeDecode(decoded, &state));
        assert(state.enabled && state.x == 1.25 && state.y == -2.5 && state.z == 0.125);
        assert([VPhoneGyroscopeEncode(state) isEqual:sample]);

        NSMutableDictionary *disabled = [sample mutableCopy];
        disabled[@"enabled"] = @NO;
        NSData *disabledWire = [NSPropertyListSerialization dataWithPropertyList:disabled
                                     format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
        id disabledRead = [NSPropertyListSerialization propertyListWithData:disabledWire options:0 format:nil error:nil];
        assert(VPhoneGyroscopeDecode(disabledRead, &state));
        assert(!state.enabled && state.x == 1.25 && state.y == -2.5 && state.z == 0.125);

        for (id invalid in @[@YES, @"1", NSNull.null, @(NAN), @(INFINITY), @1001, @-1001]) {
            NSMutableDictionary *bad = [sample mutableCopy];
            bad[@"y"] = invalid;
            assert(!VPhoneGyroscopeDecode(bad, &state));
            assert(!state.enabled && state.x == 0 && state.y == 0 && state.z == 0);
        }
        for (NSString *key in @[@"enabled", @"x", @"y", @"z"]) {
            NSMutableDictionary *bad = [sample mutableCopy];
            [bad removeObjectForKey:key];
            assert(!VPhoneGyroscopeDecode(bad, &state));
        }
        NSMutableDictionary *badFlag = [sample mutableCopy];
        badFlag[@"enabled"] = @1;
        assert(!VPhoneGyroscopeDecode(badFlag, &state));
        assert(!VPhoneGyroscopeDecode(nil, &state));
        assert(!VPhoneGyroscopeDecode(@[], &state));
        assert(VPhoneGyroscopeDecode(@{@"enabled": @NO, @"x": @0, @"y": @0, @"z": @0}, &state));
        assert(!state.enabled);
        // A hostile or broken client interval must not produce an unbounded
        // timer, overflow nanoseconds, or keep streaming after unsubscribe.
        assert(VPhoneGyroscopeInterval(@500) == 5000);
        assert(VPhoneGyroscopeInterval(@20000) == 20000);
        assert(VPhoneGyroscopeInterval(@(DBL_MAX)) == 1000000);
        for (id interval in @[@0, @-1, @YES, @"5000", @(NAN), @(INFINITY), NSNull.null])
            assert(VPhoneGyroscopeInterval(interval) == 0);
        puts("Gyroscope transport tests passed");

        // Exercise the real HID factory without creating/publishing a host
        // service. This verifies our ObjC ABI and signed axis representation.
        void *hid = dlopen("/System/Library/PrivateFrameworks/HID.framework/HID", RTLD_NOW | RTLD_LOCAL);
        assert(hid);
        Class<VPhoneGyroscopeHIDEvent> eventClass = (Class<VPhoneGyroscopeHIDEvent>)NSClassFromString(@"HIDEvent");
        assert([eventClass respondsToSelector:@selector(gyroEvent:x:y:z:options:)]);
        id<VPhoneGyroscopeHIDEvent> event = [eventClass gyroEvent:123456789 x:1.25 y:-2.5 z:0.125 options:0];
        assert(event && event.timestamp == 123456789);
        assert(event.gyroX == 1.25 && event.gyroY == -2.5 && event.gyroZ == 0.125);
        [event setGyroSequence:42];
        assert(event.gyroSequence == 42);
        event = [eventClass gyroEvent:123456790 x:0.1234567 y:-0.1234567 z:1000 options:0];
        assert(fabs(event.gyroX - 0.1234567) < 1.0 / 65536);
        assert(fabs(event.gyroY + 0.1234567) < 1.0 / 65536);
        assert(event.gyroZ == 1000 && event.timestamp == 123456790);
        puts("Gyroscope HID event factory tests passed");
    }
    return 0;
}
