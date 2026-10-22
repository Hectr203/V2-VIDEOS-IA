#import "VPhoneAttitudeSample.h"

// MARK: - Attitude snapshots

@interface VPhoneAttitude ()
@property (nonatomic) CMQuaternion value;
@end

@implementation VPhoneAttitude
- (instancetype)initWithState:(VPhoneAttitudeState)state {
    if ((self = [super init])) {
        // Core Motion: pitch about X, roll about Y, yaw about Z.
        // R = Rz(yaw) Rx(pitch) Ry(roll), in radians.
        double r = state.roll * M_PI / 360, p = state.pitch * M_PI / 360, y = state.yaw * M_PI / 360;
        double cr = cos(r), sr = sin(r), cp = cos(p), sp = sin(p), cy = cos(y), sy = sin(y);
        _value = (CMQuaternion){cy * sp * cr - sy * cp * sr,
                               cy * cp * sr + sy * sp * cr,
                               cy * sp * sr + sy * cp * cr,
                               cy * cp * cr - sy * sp * sr};
    }
    return self;
}
- (CMQuaternion)quaternion { return self.value; }
- (CMRotationMatrix)rotationMatrix {
    CMQuaternion q = self.value;
    return (CMRotationMatrix){1-2*(q.y*q.y+q.z*q.z), 2*(q.x*q.y-q.z*q.w), 2*(q.x*q.z+q.y*q.w),
                              2*(q.x*q.y+q.z*q.w), 1-2*(q.x*q.x+q.z*q.z), 2*(q.y*q.z-q.x*q.w),
                              2*(q.x*q.z-q.y*q.w), 2*(q.y*q.z+q.x*q.w), 1-2*(q.x*q.x+q.y*q.y)};
}
- (double)roll { CMRotationMatrix m = self.rotationMatrix; return atan2(-m.m31, m.m33); }
- (double)pitch { return asin(fmax(-1, fmin(1, self.rotationMatrix.m32))); }
- (double)yaw { CMRotationMatrix m = self.rotationMatrix; return atan2(-m.m12, m.m22); }
- (void)multiplyByInverseOfAttitude:(CMAttitude *)attitude {
    CMQuaternion a = self.value, b = attitude.quaternion;
    double norm = b.x*b.x + b.y*b.y + b.z*b.z + b.w*b.w;
    if (!isfinite(norm) || norm <= 0) return;
    b = (CMQuaternion){-b.x/norm, -b.y/norm, -b.z/norm, b.w/norm};
    CMQuaternion q = {a.w*b.x+a.x*b.w+a.y*b.z-a.z*b.y,
                      a.w*b.y-a.x*b.z+a.y*b.w+a.z*b.x,
                      a.w*b.z+a.x*b.y-a.y*b.x+a.z*b.w,
                      a.w*b.w-a.x*b.x-a.y*b.y-a.z*b.z};
    double length = sqrt(q.x*q.x + q.y*q.y + q.z*q.z + q.w*q.w);
    if (isfinite(length) && length > 0)
        self.value = (CMQuaternion){q.x/length, q.y/length, q.z/length, q.w/length};
}
- (id)copyWithZone:(NSZone *)zone {
    VPhoneAttitude *copy = [[VPhoneAttitude allocWithZone:zone] initWithState:(VPhoneAttitudeState){0}];
    copy.value = self.value;
    return copy;
}
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeDouble:self.value.x forKey:@"x"]; [coder encodeDouble:self.value.y forKey:@"y"];
    [coder encodeDouble:self.value.z forKey:@"z"]; [coder encodeDouble:self.value.w forKey:@"w"];
}
- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [self initWithState:(VPhoneAttitudeState){0}])) {
        CMQuaternion q = {[coder decodeDoubleForKey:@"x"], [coder decodeDoubleForKey:@"y"],
                          [coder decodeDoubleForKey:@"z"], [coder decodeDoubleForKey:@"w"]};
        double norm = sqrt(q.x*q.x + q.y*q.y + q.z*q.z + q.w*q.w);
        if (!isfinite(norm) || norm <= 0) return nil;
        self.value = (CMQuaternion){q.x/norm, q.y/norm, q.z/norm, q.w/norm};
    }
    return self;
}
@end

// MARK: - Stationary device motion

@interface VPhoneAttitudeSample ()
@property (nonatomic, strong) VPhoneAttitude *pose;
@property (nonatomic) NSTimeInterval sampleTime;
@end

@implementation VPhoneAttitudeSample
- (instancetype)initWithState:(VPhoneAttitudeState)state timestamp:(NSTimeInterval)timestamp {
    if ((self = [super init])) {
        _pose = [[VPhoneAttitude alloc] initWithState:state];
        _sampleTime = timestamp;
    }
    return self;
}
- (CMAttitude *)attitude { return self.pose; }
- (NSTimeInterval)timestamp { return self.sampleTime; }
- (CMAcceleration)gravity {
    CMRotationMatrix m = self.pose.rotationMatrix;
    return (CMAcceleration){-m.m31, -m.m32, -m.m33};
}
- (CMAcceleration)userAcceleration { return (CMAcceleration){0}; }
- (CMRotationRate)rotationRate { return (CMRotationRate){0}; }
- (CMCalibratedMagneticField)magneticField {
    return (CMCalibratedMagneticField){{0}, CMMagneticFieldCalibrationAccuracyUncalibrated};
}
- (double)heading { return -1; }
- (double)headingAccuracy { return -1; }
- (CMDeviceMotionSensorLocation)sensorLocation { return CMDeviceMotionSensorLocationDefault; }
- (id)copyWithZone:(NSZone *)zone {
    VPhoneAttitudeSample *copy = [[VPhoneAttitudeSample allocWithZone:zone]
        initWithState:(VPhoneAttitudeState){0} timestamp:self.sampleTime];
    copy.pose = [self.pose copy];
    return copy;
}
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.pose forKey:@"pose"];
    [coder encodeDouble:self.sampleTime forKey:@"timestamp"];
}
- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [self initWithState:(VPhoneAttitudeState){0} timestamp:[coder decodeDoubleForKey:@"timestamp"]])) {
        self.pose = [coder decodeObjectOfClass:VPhoneAttitude.class forKey:@"pose"];
        if (!self.pose || !isfinite(self.sampleTime)) return nil;
    }
    return self;
}
@end
