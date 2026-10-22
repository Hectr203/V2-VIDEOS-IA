#pragma once
#import <CoreMotion/CoreMotion.h>
#import "VPhoneAttitudeState.h"

// A stationary pose in XArbitraryZVertical. No magnetic/true-north claim.
@interface VPhoneAttitude : CMAttitude
- (instancetype)initWithState:(VPhoneAttitudeState)state;
@end

@interface VPhoneAttitudeSample : CMDeviceMotion
- (instancetype)initWithState:(VPhoneAttitudeState)state timestamp:(NSTimeInterval)timestamp;
@end
