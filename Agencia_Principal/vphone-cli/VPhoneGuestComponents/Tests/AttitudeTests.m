#import "VPhoneAttitudeSample.h"
#include <assert.h>

static void closeTo(double actual, double expected) { assert(fabs(actual - expected) < 1e-9); }

int main(void) {
    @autoreleasepool {
        VPhoneAttitudeState state = {YES, 32.5, -24.25, 117.75}, decoded;
        assert(VPhoneAttitudeDecode(VPhoneAttitudeEncode(state), &decoded));
        closeTo(decoded.roll, state.roll);
        for (NSDictionary *invalid in @[
            @{@"enabled": @YES, @"roll": @YES, @"pitch": @0, @"yaw": @0},
            @{@"enabled": @1, @"roll": @0, @"pitch": @0, @"yaw": @0},
            @{@"enabled": @YES, @"roll": @181, @"pitch": @0, @"yaw": @0},
            @{@"enabled": @YES, @"roll": @0, @"pitch": @91, @"yaw": @0},
            @{@"enabled": @YES, @"roll": @0, @"pitch": @0, @"yaw": @(NAN)},
        ]) assert(!VPhoneAttitudeDecode(invalid, &decoded));
        VPhoneAttitudeState poses[] = {state, {NO, -180, -90, -180}, {YES, 180, 90, 180}, {YES, 0, 0, 0}};
        for (NSUInteger i = 0; i < sizeof(poses)/sizeof(*poses); i++) {
            decoded = VPhoneAttitudeUnpack(VPhoneAttitudePack(poses[i]));
            assert(decoded.enabled == poses[i].enabled);
            closeTo(decoded.roll, poses[i].roll); closeTo(decoded.pitch, poses[i].pitch); closeTo(decoded.yaw, poses[i].yaw);
        }
        assert(!VPhoneAttitudeUnpack(0).enabled);
        assert(!VPhoneAttitudeUnpack(UINT64_MAX).enabled);
        VPhoneAttitudeSample *sample = [[VPhoneAttitudeSample alloc] initWithState:state timestamp:123];
        CMAttitude *pose = sample.attitude;
        closeTo(pose.roll, state.roll*M_PI/180); closeTo(pose.pitch, state.pitch*M_PI/180); closeTo(pose.yaw, state.yaw*M_PI/180);
        CMQuaternion q = pose.quaternion;
        closeTo(q.x*q.x+q.y*q.y+q.z*q.z+q.w*q.w, 1);
        CMRotationMatrix m = pose.rotationMatrix;
        closeTo(m.m11*m.m11+m.m12*m.m12+m.m13*m.m13, 1);
        closeTo(m.m11*m.m21+m.m12*m.m22+m.m13*m.m23, 0);
        CMAcceleration g = sample.gravity;
        closeTo(g.x*g.x+g.y*g.y+g.z*g.z, 1);
        closeTo(sample.rotationRate.x, 0); closeTo(sample.userAcceleration.y, 0); closeTo(sample.timestamp, 123);
        assert(sample.heading < 0 && sample.magneticField.accuracy == CMMagneticFieldCalibrationAccuracyUncalibrated);
        CMAttitude *copy = [pose copy];
        [copy multiplyByInverseOfAttitude:pose];
        closeTo(copy.quaternion.w, 1); closeTo(copy.roll, 0); closeTo(copy.pitch, 0); closeTo(copy.yaw, 0);
        closeTo(pose.roll, state.roll*M_PI/180);
        NSError *error;
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:sample requiringSecureCoding:YES error:&error];
        assert(archive && !error);
        VPhoneAttitudeSample *restored = [NSKeyedUnarchiver unarchivedObjectOfClass:VPhoneAttitudeSample.class fromData:archive error:&error];
        assert(restored && !error);
        closeTo(restored.attitude.yaw, pose.yaw); closeTo(restored.timestamp, 123);
        VPhoneAttitudeSample *pitch = [[VPhoneAttitudeSample alloc] initWithState:(VPhoneAttitudeState){YES, 0, 90, 0} timestamp:0];
        closeTo(pitch.gravity.y, -1);
        VPhoneAttitudeSample *roll = [[VPhoneAttitudeSample alloc] initWithState:(VPhoneAttitudeState){YES, 90, 0, 0} timestamp:0];
        closeTo(roll.gravity.x, 1);
        puts("Attitude configuration, quaternion, gravity, copy and coding tests passed");
    }
    return 0;
}
