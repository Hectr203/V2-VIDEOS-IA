/*
 * vphoned_apps — register a restored removable system app with LaunchServices.
 *
 * `apps.restore_system` moves an Apple app's bundle container back to its
 * original UUID path and must register the bundle again. icli's registerApp
 * (since 0.7.17) refuses Apple's apps and apps another installer put in a
 * container, so this calls LSApplicationWorkspace directly, the way uicache
 * does for a system app:
 *
 *   1. registerApplication: with the bundle URL;
 *   2. registerApplicationDictionary: with the Info.plist, Path and a System,
 *      deletable application type (iOS 27 answers NO and registers nothing);
 *   3. the containerized interface with the same dictionary plus the bundle
 *      container.
 *
 * After each attempt LaunchServices is asked, for up to a second, whether it
 * lists the identifier at this path; the first attempt it does ends the call.
 * The Swift caller reads the registration back again through icli.
 */

#import "Include/VphonedNative.h"

#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <unistd.h>

@interface NSObject (VPhoneLaunchServices)
+ (id)defaultWorkspace;
+ (id)applicationProxyForIdentifier:(NSString *)identifier;
- (BOOL)registerApplication:(NSURL *)url;
- (BOOL)registerApplicationDictionary:(NSDictionary *)dictionary;
- (BOOL)registerContainerizedApplicationWithInfoDictionaries:(NSArray *)infos
                                               operationUUID:(NSUUID *)uuid
                                              requestContext:(id)context
                                                saveObserver:(id)observer
                                           registrationError:(NSError **)error;
- (NSURL *)bundleURL;
@end

// MARK: - Read Back

static NSString *vp_apps_comparable(NSString *path) {
    NSString *resolved = path.stringByResolvingSymlinksInPath.stringByStandardizingPath;
    if ([resolved hasPrefix:@"/private/var/"]) resolved = [resolved substringFromIndex:@"/private".length];
    while (resolved.length > 1 && [resolved hasSuffix:@"/"]) resolved = [resolved substringToIndex:resolved.length - 1];
    return resolved;
}

static BOOL vp_apps_listed(NSString *bundleID, NSString *path) {
    Class proxyClass = NSClassFromString(@"LSApplicationProxy");
    if (![proxyClass respondsToSelector:@selector(applicationProxyForIdentifier:)]) return NO;
    NSString *expected = vp_apps_comparable(path);
    for (int attempt = 0; attempt < 10; attempt++) {
        if (attempt) usleep(100 * 1000);
        id proxy = [proxyClass applicationProxyForIdentifier:bundleID];
        NSURL *url = [proxy respondsToSelector:@selector(bundleURL)] ? [proxy bundleURL] : nil;
        if (url.path && [vp_apps_comparable(url.path) isEqualToString:expected]) return YES;
    }
    return NO;
}

// MARK: - Registration

char *vp_ls_register_system_app(const char *app_path, const char *container_path, char **method) {
    if (method) *method = NULL;
    @autoreleasepool {
        if (!app_path || !container_path) return strdup("no app path");
        NSString *path = @(app_path);
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Info.plist"]];
        NSString *bundleID = info[@"CFBundleIdentifier"];
        if (![bundleID isKindOfClass:NSString.class] || !bundleID.length) {
            return strdup([NSString stringWithFormat:@"%@ has no bundle identifier", path].UTF8String);
        }
        Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
        id workspace = [workspaceClass respondsToSelector:@selector(defaultWorkspace)] ? [workspaceClass defaultWorkspace] : nil;
        if (!workspace) return strdup("LSApplicationWorkspace is unavailable");

        if ([workspace respondsToSelector:@selector(registerApplication:)]
            && [workspace registerApplication:[NSURL fileURLWithPath:path isDirectory:YES]]
            && vp_apps_listed(bundleID, path)) {
            if (method) *method = strdup("registerApplication");
            return NULL;
        }

        NSMutableDictionary *dictionary = [info mutableCopy];
        dictionary[@"Path"] = path;
        dictionary[@"ApplicationType"] = @"System";
        dictionary[@"IsDeletable"] = @YES;
        if ([NSFileManager.defaultManager fileExistsAtPath:[path stringByAppendingPathComponent:@"Settings.bundle/Root.plist"]]) {
            dictionary[@"HasSettingsBundle"] = @YES;
        }
        if ([workspace respondsToSelector:@selector(registerApplicationDictionary:)]
            && [workspace registerApplicationDictionary:dictionary]
            && vp_apps_listed(bundleID, path)) {
            if (method) *method = strdup("registerApplicationDictionary");
            return NULL;
        }

        SEL containerized = @selector(
            registerContainerizedApplicationWithInfoDictionaries:operationUUID:requestContext:saveObserver:registrationError:);
        if ([workspace respondsToSelector:containerized]) {
            NSMutableDictionary *record = [dictionary mutableCopy];
            record[@"CodeInfoIdentifier"] = bundleID;
            record[@"BundleContainer"] = @(container_path);
            record[@"CompatibilityState"] = @0;
            record[@"SignerIdentity"] = @"Apple iPhone OS Application Signing";
            record[@"SignerOrganization"] = @"Apple Inc.";
            NSError *error = nil;
            [workspace registerContainerizedApplicationWithInfoDictionaries:@[record]
                                                              operationUUID:[NSUUID UUID]
                                                             requestContext:nil
                                                               saveObserver:nil
                                                          registrationError:&error];
            if (!error && vp_apps_listed(bundleID, path)) {
                if (method) *method = strdup("registerContainerizedApplication");
                return NULL;
            }
            if (error) {
                return strdup([NSString stringWithFormat:@"LaunchServices refused %@: %@", bundleID,
                                                         error.localizedDescription].UTF8String);
            }
        }
        return strdup([NSString stringWithFormat:@"LaunchServices does not list %@ at %@ after registration", bundleID,
                                                 path].UTF8String);
    }
}
