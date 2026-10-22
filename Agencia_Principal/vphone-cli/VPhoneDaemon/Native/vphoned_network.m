/*
 * The guest NIC's IPv4 configuration, read and written through configd's
 * network preferences (/var/preferences/SystemConfiguration/preferences.plist).
 *
 * iOS ships SCPreferences but its SDK marks the calls unavailable, so every
 * entry point is resolved with dlsym, as vphoned_touch.m does for IOKit.
 * Writing needs com.apple.SystemConfiguration.SCPreferences-write-access,
 * which vphoned already carries.
 *
 * A manual configuration written here is marked with kManagedKey. Only a
 * marked one is ever turned back into DHCP, so an address the user typed in
 * the guest's own Settings survives a host that asks for DHCP.
 */

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#include <dlfcn.h>
#include <arpa/inet.h>

#import "VphonedNative.h"

static NSString *const kManagedKey = @"VPhoneManaged";

typedef SCPreferencesRef (*CreateFn)(CFAllocatorRef, CFStringRef, CFStringRef);
typedef Boolean (*LockFn)(SCPreferencesRef, Boolean);
typedef Boolean (*PrefsFn)(SCPreferencesRef);
typedef CFPropertyListRef (*GetValueFn)(SCPreferencesRef, CFStringRef);
typedef Boolean (*SetValueFn)(SCPreferencesRef, CFStringRef, CFPropertyListRef);
typedef int (*ErrorFn)(void);

static CreateFn pCreate;
static LockFn pLock;
static PrefsFn pUnlock, pCommit, pApply;
static GetValueFn pGetValue;
static SetValueFn pSetValue;
static ErrorFn pError;

static BOOL vp_network_load(NSString **error) {
    static BOOL loaded;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *sc = dlopen("/System/Library/Frameworks/SystemConfiguration.framework/SystemConfiguration", RTLD_NOW);
        if (!sc) return;
        pCreate = (CreateFn)dlsym(sc, "SCPreferencesCreate");
        pLock = (LockFn)dlsym(sc, "SCPreferencesLock");
        pUnlock = (PrefsFn)dlsym(sc, "SCPreferencesUnlock");
        pCommit = (PrefsFn)dlsym(sc, "SCPreferencesCommitChanges");
        pApply = (PrefsFn)dlsym(sc, "SCPreferencesApplyChanges");
        pGetValue = (GetValueFn)dlsym(sc, "SCPreferencesGetValue");
        pSetValue = (SetValueFn)dlsym(sc, "SCPreferencesSetValue");
        pError = (ErrorFn)dlsym(sc, "SCError");
        loaded = pCreate && pLock && pUnlock && pCommit && pApply && pGetValue && pSetValue && pError;
    });
    if (!loaded && error) *error = @"SCPreferences is not available on this guest";
    return loaded;
}

static NSString *vp_sc_error(NSString *step) {
    return [NSString stringWithFormat:@"%@ failed (SCError %d)", step, pError ? pError() : -1];
}

/// The service ID whose interface is `interface`, from a NetworkServices dict.
static NSString *vp_service_for_interface(NSDictionary *services, NSString *interface) {
    for (NSString *serviceID in services) {
        NSDictionary *service = services[serviceID];
        if (![service isKindOfClass:NSDictionary.class]) continue;
        NSDictionary *iface = service[@"Interface"];
        if ([iface isKindOfClass:NSDictionary.class] && [iface[@"DeviceName"] isEqual:interface]) {
            return serviceID;
        }
    }
    return nil;
}

static NSDictionary *vp_describe(NSString *interface, NSString *serviceID, NSDictionary *service) {
    NSDictionary *ipv4 = [service[@"IPv4"] isKindOfClass:NSDictionary.class] ? service[@"IPv4"] : @{};
    NSDictionary *dns = [service[@"DNS"] isKindOfClass:NSDictionary.class] ? service[@"DNS"] : @{};
    NSString *method = ipv4[@"ConfigMethod"] ?: @"";
    NSMutableDictionary *out = [@{
        @"interface": interface,
        @"service": serviceID,
        @"method": [method isEqualToString:@"Manual"] ? @"manual" : ([method isEqualToString:@"DHCP"] ? @"dhcp" : method),
        @"managed": @([ipv4[kManagedKey] boolValue]),
    } mutableCopy];
    NSArray *addresses = ipv4[@"Addresses"];
    NSArray *masks = ipv4[@"SubnetMasks"];
    if ([addresses isKindOfClass:NSArray.class] && addresses.count) out[@"address"] = addresses.firstObject;
    if ([masks isKindOfClass:NSArray.class] && masks.count) out[@"subnet_mask"] = masks.firstObject;
    if ([ipv4[@"Router"] isKindOfClass:NSString.class]) out[@"router"] = ipv4[@"Router"];
    NSArray *servers = dns[@"ServerAddresses"];
    out[@"dns"] = [servers isKindOfClass:NSArray.class] ? servers : @[];
    return out;
}

static BOOL vp_is_ipv4(id value) {
    struct in_addr parsed;
    return [value isKindOfClass:NSString.class] && inet_pton(AF_INET, [value UTF8String], &parsed) == 1;
}

NSDictionary *vp_network_ipv4_get(NSString *interface, NSString **error) {
    if (!vp_network_load(error)) return nil;
    SCPreferencesRef prefs = pCreate(NULL, CFSTR("vphoned"), NULL);
    if (!prefs) {
        if (error) *error = vp_sc_error(@"SCPreferencesCreate");
        return nil;
    }
    NSDictionary *services = (__bridge NSDictionary *)pGetValue(prefs, CFSTR("NetworkServices"));
    NSString *serviceID = [services isKindOfClass:NSDictionary.class] ? vp_service_for_interface(services, interface) : nil;
    NSDictionary *result = nil;
    if (serviceID) {
        result = vp_describe(interface, serviceID, services[serviceID]);
    } else if (error) {
        *error = [NSString stringWithFormat:@"no network service for %@", interface];
    }
    CFRelease(prefs);
    return result;
}

NSDictionary *vp_network_ipv4_set(NSString *interface, NSDictionary *params, NSString **error) {
    if (!vp_network_load(error)) return nil;

    NSString *method = params[@"method"];
    BOOL manual = [method isEqual:@"manual"];
    if (!manual && ![method isEqual:@"dhcp"]) {
        if (error) *error = @"method must be manual or dhcp";
        return nil;
    }
    NSArray *dns = params[@"dns"] ?: @[];
    if (manual) {
        BOOL dnsValid = [dns isKindOfClass:NSArray.class];
        for (id server in dnsValid ? dns : @[]) dnsValid = dnsValid && vp_is_ipv4(server);
        if (!vp_is_ipv4(params[@"address"]) || !vp_is_ipv4(params[@"subnet_mask"]) || !vp_is_ipv4(params[@"router"]) || !dnsValid) {
            if (error) *error = @"manual needs address, subnet_mask, router and dns as dotted IPv4 addresses";
            return nil;
        }
    }

    SCPreferencesRef prefs = pCreate(NULL, CFSTR("vphoned"), NULL);
    if (!prefs) {
        if (error) *error = vp_sc_error(@"SCPreferencesCreate");
        return nil;
    }
    if (!pLock(prefs, true)) {
        if (error) *error = vp_sc_error(@"SCPreferencesLock");
        CFRelease(prefs);
        return nil;
    }

    NSDictionary *result = nil;
    NSDictionary *services = (__bridge NSDictionary *)pGetValue(prefs, CFSTR("NetworkServices"));
    NSString *serviceID = [services isKindOfClass:NSDictionary.class] ? vp_service_for_interface(services, interface) : nil;
    if (!serviceID) {
        if (error) *error = [NSString stringWithFormat:@"no network service for %@", interface];
        goto done;
    }

    {
        NSDictionary *service = services[serviceID];
        NSDictionary *oldIPv4 = [service[@"IPv4"] isKindOfClass:NSDictionary.class] ? service[@"IPv4"] : @{};
        NSDictionary *oldDNS = [service[@"DNS"] isKindOfClass:NSDictionary.class] ? service[@"DNS"] : @{};
        BOOL managed = [oldIPv4[kManagedKey] boolValue];

        NSDictionary *ipv4;
        NSDictionary *dnsEntry;
        if (manual) {
            ipv4 = @{
                @"ConfigMethod": @"Manual",
                @"Addresses": @[params[@"address"]],
                @"SubnetMasks": @[params[@"subnet_mask"]],
                @"Router": params[@"router"],
                kManagedKey: @YES,
            };
            dnsEntry = dns.count ? @{@"ServerAddresses": dns, kManagedKey: @YES} : @{};
        } else if (managed) {
            ipv4 = @{@"ConfigMethod": @"DHCP"};
            dnsEntry = [oldDNS[kManagedKey] boolValue] ? @{} : oldDNS;
        } else {
            // DHCP asked for, and nothing of ours to undo.
            ipv4 = oldIPv4;
            dnsEntry = oldDNS;
        }

        BOOL changed = ![ipv4 isEqualToDictionary:oldIPv4] || ![dnsEntry isEqualToDictionary:oldDNS];
        if (changed) {
            NSMutableDictionary *newService = [service mutableCopy];
            newService[@"IPv4"] = ipv4;
            newService[@"DNS"] = dnsEntry;
            NSMutableDictionary *newServices = [services mutableCopy];
            newServices[serviceID] = newService;
            if (!pSetValue(prefs, CFSTR("NetworkServices"), (__bridge CFDictionaryRef)newServices)) {
                if (error) *error = vp_sc_error(@"SCPreferencesSetValue");
                goto done;
            }
            if (!pCommit(prefs)) {
                if (error) *error = vp_sc_error(@"SCPreferencesCommitChanges");
                goto done;
            }
            if (!pApply(prefs)) {
                if (error) *error = vp_sc_error(@"SCPreferencesApplyChanges");
                goto done;
            }
        }
        NSMutableDictionary *described = [vp_describe(interface, serviceID, @{@"IPv4": ipv4, @"DNS": dnsEntry}) mutableCopy];
        described[@"changed"] = @(changed);
        result = described;
    }

done:
    pUnlock(prefs);
    CFRelease(prefs);
    return result;
}

/*
 * The guest's mDNS name, System/Network/HostNames/LocalHostName in the same
 * preferences. mDNSResponder announces it as <name>.local. The name in place
 * before vphoned first set one is kept under kOriginalNameKey, so turning the
 * feature off puts it back, and only a name vphoned set is ever undone.
 */

static NSString *const kOriginalNameKey = @"VPhoneOriginalLocalHostName";

static NSDictionary *vp_host_names(SCPreferencesRef prefs) {
    NSDictionary *system = (__bridge NSDictionary *)pGetValue(prefs, CFSTR("System"));
    NSDictionary *network = [system isKindOfClass:NSDictionary.class] ? system[@"Network"] : nil;
    NSDictionary *names = [network isKindOfClass:NSDictionary.class] ? network[@"HostNames"] : nil;
    return [names isKindOfClass:NSDictionary.class] ? names : @{};
}

static NSDictionary *vp_describe_host_names(NSDictionary *names) {
    NSString *name = names[@"LocalHostName"];
    return @{
        @"local_host_name": [name isKindOfClass:NSString.class] ? name : NSNull.null,
        @"managed": names[kOriginalNameKey] != nil ? @YES : @NO,
    };
}

static BOOL vp_is_host_label(NSString *name) {
    if (name.length < 1 || name.length > 63 || [name hasPrefix:@"-"] || [name hasSuffix:@"-"]) return NO;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
        @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-"];
    return [name rangeOfCharacterFromSet:allowed.invertedSet].location == NSNotFound;
}

NSDictionary *vp_network_hostname_get(NSString **error) {
    if (!vp_network_load(error)) return nil;
    SCPreferencesRef prefs = pCreate(NULL, CFSTR("vphoned"), NULL);
    if (!prefs) {
        if (error) *error = vp_sc_error(@"SCPreferencesCreate");
        return nil;
    }
    NSDictionary *result = vp_describe_host_names(vp_host_names(prefs));
    CFRelease(prefs);
    return result;
}

NSDictionary *vp_network_hostname_set(NSString *name, NSString **error) {
    if (!vp_network_load(error)) return nil;
    if (name && !vp_is_host_label(name)) {
        if (error) *error = @"local_host_name must be 1-63 letters, digits and hyphens";
        return nil;
    }
    SCPreferencesRef prefs = pCreate(NULL, CFSTR("vphoned"), NULL);
    if (!prefs) {
        if (error) *error = vp_sc_error(@"SCPreferencesCreate");
        return nil;
    }
    if (!pLock(prefs, true)) {
        if (error) *error = vp_sc_error(@"SCPreferencesLock");
        CFRelease(prefs);
        return nil;
    }

    NSDictionary *result = nil;
    NSDictionary *old = vp_host_names(prefs);
    NSMutableDictionary *names = [old mutableCopy];
    BOOL managed = names[kOriginalNameKey] != nil;
    if (name) {
        if (!managed) names[kOriginalNameKey] = names[@"LocalHostName"] ?: @"";
        names[@"LocalHostName"] = name;
    } else if (managed) {
        NSString *original = names[kOriginalNameKey];
        if ([original isKindOfClass:NSString.class] && original.length) {
            names[@"LocalHostName"] = original;
        } else {
            [names removeObjectForKey:@"LocalHostName"];
        }
        [names removeObjectForKey:kOriginalNameKey];
    }

    BOOL changed = ![names isEqualToDictionary:old];
    if (changed) {
        NSDictionary *oldSystem = (__bridge NSDictionary *)pGetValue(prefs, CFSTR("System"));
        NSMutableDictionary *system = [oldSystem isKindOfClass:NSDictionary.class] ? [oldSystem mutableCopy] : [NSMutableDictionary dictionary];
        NSMutableDictionary *network = [system[@"Network"] isKindOfClass:NSDictionary.class] ? [system[@"Network"] mutableCopy] : [NSMutableDictionary dictionary];
        network[@"HostNames"] = names;
        system[@"Network"] = network;
        if (!pSetValue(prefs, CFSTR("System"), (__bridge CFDictionaryRef)system)) {
            if (error) *error = vp_sc_error(@"SCPreferencesSetValue");
            goto done;
        }
        if (!pCommit(prefs)) {
            if (error) *error = vp_sc_error(@"SCPreferencesCommitChanges");
            goto done;
        }
        if (!pApply(prefs)) {
            if (error) *error = vp_sc_error(@"SCPreferencesApplyChanges");
            goto done;
        }
    }
    {
        NSMutableDictionary *described = [vp_describe_host_names(names) mutableCopy];
        described[@"changed"] = @(changed);
        result = described;
    }

done:
    pUnlock(prefs);
    CFRelease(prefs);
    return result;
}


BOOL vp_preferences_apply(NSString **error) {
    if (!vp_network_load(error)) return NO;
    SCPreferencesRef prefs = pCreate(NULL, CFSTR("vphoned"), NULL);
    if (!prefs) {
        if (error) *error = vp_sc_error(@"SCPreferencesCreate");
        return NO;
    }
    BOOL applied = NO;
    if (!pLock(prefs, true)) {
        if (error) *error = vp_sc_error(@"SCPreferencesLock");
    } else {
        applied = pApply(prefs);
        if (!applied && error) *error = vp_sc_error(@"SCPreferencesApplyChanges");
        pUnlock(prefs);
    }
    CFRelease(prefs);
    return applied;
}
