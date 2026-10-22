// MISFixProfileScope.c — let every provisioning profile cover this device.
//
// A profile carries the list of devices it is good for, and misagent reads it
// itself rather than asking anyone:
//
//     ProvisionedDevices   ProvisionsAllDevices
//
// — its own strings, in the order the code uses them. It asks the profile for
// `ProvisionsAllDevices` first, and only when that is false does it compare
// this device's UDID against `ProvisionedDevices`. A VM's UDID is in nobody's
// list, so the comparison always loses and the profile is refused with
// `0xE8008012`.
//
// Both questions are asked through `MISProfileGetValue`, which is libmis's and
// so is a callee this dylib can replace. Answering the first one `true` means
// the second is never asked, and a profile that reaches this guest installs.
//
// ## Why this rather than a borrowed UDID
//
// MISFixDeviceIdentity.c answers `UniqueDeviceID` with a device someone has
// already registered, which makes the comparison succeed for one team's
// profiles. It works, and it needs a registered device to borrow, a UDID
// typed in per machine, and it is still wrong for every other team. This says
// the same thing once, for every profile, and needs no configuration.
//
// ## What it buys
//
// The install path stops needing anything faked. With the profile installed
// for real, libmis validates the app against it — genuine signer, genuine
// entitlements, `ValidatedByProfile = 1` — instead of being talked past in
// MISFixInstallPolicy.c. The profile's own signature, its expiry and its
// application-identifier are all still checked; the only claim widened is
// which devices it covers.
//
// ## What it does not touch
//
// Nothing about a profile is rewritten. `MISProfileGetValue` is asked a
// question and answered; the profile on disk, its signature and every other
// value it carries are exactly as Apple issued them.

#include "MISFixConfig.h"
#include "MISFixDetour.h"

#include <CoreFoundation/CoreFoundation.h>

/// The key whose answer decides whether the device list is consulted at all.
/// A plain string for the same reason as the MIS option keys: libmis exports
/// no symbol for it and the SDK declares none.
#define kMISProfileProvisionsAllDevices CFSTR("ProvisionsAllDevices")

typedef CFTypeRef (*MISProfileGet)(CFTypeRef profile, CFStringRef key);

extern CFTypeRef MISProfileGetValue(CFTypeRef profile, CFStringRef key);

static MISProfileGet vpOriginalProfileGetValue;

static CFTypeRef vpProfileGetValue(CFTypeRef profile, CFStringRef key) {
    if (key != NULL && CFGetTypeID(key) == CFStringGetTypeID()
        && CFEqual(key, kMISProfileProvisionsAllDevices))
    {
        MISFixLog("MISProfileGetValue(ProvisionsAllDevices) -> true");
        // Immortal, and the real function returns a borrowed value too, so the
        // caller's lifetime expectations are unchanged.
        return kCFBooleanTrue;
    }
    return vpOriginalProfileGetValue(profile, key);
}

__attribute__((constructor)) static void vpInstallProfileScopeHook(void) {
    if (MISFixProcessOnlyNeedsIdentity())
        return;
    MISFixDetourResult result = MISFixDetour(
        "MISProfileGetValue",
        (void *)&MISProfileGetValue,
        (void *)&vpProfileGetValue,
        (void **)&vpOriginalProfileGetValue
    );
    if (result != MISFixDetourOK)
        MISFixNote("MISProfileGetValue not hooked: %s", MISFixDetourDescribe(result));
}
