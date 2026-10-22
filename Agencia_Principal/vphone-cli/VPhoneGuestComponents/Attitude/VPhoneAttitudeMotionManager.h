#pragma once
#import <CoreMotion/CoreMotion.h>

// Public CMMotionManager selectors, sent through the runtime so the same
// injection can be exercised on a host whose SDK hides this iOS class.
@protocol VPhoneAttitudeMotionManager <NSObject>
@property (nonatomic) NSTimeInterval deviceMotionUpdateInterval;
@property (readonly, getter=isDeviceMotionAvailable) BOOL deviceMotionAvailable;
@property (readonly, getter=isDeviceMotionActive) BOOL deviceMotionActive;
@property (readonly) CMDeviceMotion *deviceMotion;
@property (readonly) CMAttitudeReferenceFrame attitudeReferenceFrame;
+ (CMAttitudeReferenceFrame)availableAttitudeReferenceFrames;
- (void)startDeviceMotionUpdates;
- (void)startDeviceMotionUpdatesUsingReferenceFrame:(CMAttitudeReferenceFrame)frame;
- (void)startDeviceMotionUpdatesToQueue:(NSOperationQueue *)queue withHandler:(CMDeviceMotionHandler)handler;
- (void)startDeviceMotionUpdatesUsingReferenceFrame:(CMAttitudeReferenceFrame)frame toQueue:(NSOperationQueue *)queue withHandler:(CMDeviceMotionHandler)handler;
- (void)stopDeviceMotionUpdates;
@end
