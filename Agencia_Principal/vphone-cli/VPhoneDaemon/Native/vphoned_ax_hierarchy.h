#pragma once
#import <Foundation/Foundation.h>
typedef struct {
 CFTypeRef (*createApp)(pid_t);
 int (*copy)(CFTypeRef,CFStringRef,CFTypeRef *);
 int (*setTimeout)(CFTypeRef,float);
 CFTypeID (*elementTypeID)(void);
 CFTypeID (*valueTypeID)(void);
 Boolean (*getValue)(CFTypeRef,int,void *);
} VPAxFunctions;
NSDictionary *vp_ax_walk(VPAxFunctions functions, CFTypeRef root, pid_t pid, int maxElements, int maxDepth, int timeoutMS);
// switchesEnabled is true only when this invocation enabled a previously disabled AX switch.
NSDictionary *vp_ax_walk_with_readiness(VPAxFunctions functions, CFTypeRef root, pid_t pid, int maxElements, int maxDepth, int timeoutMS, BOOL switchesEnabled);
NSDictionary *vp_ax_hierarchy(int pid, int maxElements, int maxDepth, int timeoutMS);
