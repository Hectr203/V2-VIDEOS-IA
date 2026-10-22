#pragma once
#import <Foundation/Foundation.h>

// Small ABI surface from Apple's IOHIDFamily HIDVirtualEventService.h and
// HIDEventAccessors.h. Classes are resolved at runtime, as with the camera
// hook; no private framework stub or third-party loader is needed.
@protocol VPhoneGyroscopeHIDEvent <NSObject>
+ (id)gyroEvent:(uint64_t)timestamp x:(double)x y:(double)y z:(double)z options:(uint32_t)options;
- (void)setGyroSequence:(uint32_t)sequence;
@property (readonly) uint32_t gyroSequence;
@property (readonly) double gyroX;
@property (readonly) double gyroY;
@property (readonly) double gyroZ;
@property (readonly) uint64_t timestamp;
@end

@protocol VPhoneGyroscopeHIDService <NSObject>
@property (weak) id delegate;
@property (readonly) uint64_t serviceID;
- (void)setDispatchQueue:(dispatch_queue_t)queue;
- (void)setCancelHandler:(dispatch_block_t)handler;
- (void)activate;
- (void)cancel;
- (BOOL)dispatchEvent:(id)event;
@end
