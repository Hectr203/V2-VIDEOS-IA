// MISFixDeviceIdentity.c — answer the profile check with a chosen UDID.
//
// A provisioning profile names the devices it covers. misagent refuses to
// install one that does not name this device:
//
//     Failed to install embedded profile for plus.yellow.AirBuild : 0xE8008012
//       (This provisioning profile cannot be installed on this device.)
//       -[MIInstallableBundle _installEmbeddedProfilesWithError:]
//
// which is correct — a VM's UDID is not in anyone's `ProvisionedDevices`
// unless Xcode has just registered it, and Xcode can only do that for a free
// personal team. For a paid team the VM would have to be added to the account
// by hand, and again after every `vm create`.
//
// ## Where the comparison gets its UDID
//
// misagent carries the same UDID-query helper libmis does — its strings give
// the order outright:
//
//     amfi_emulate_device_udid / "Using emulated device UDID: %{public}@"
//     "got NULL when querying UDID" / "got non-string when querying UDID"
//     "could not get device UDID" / deviceUDID / UniqueDeviceID
//     ProvisionedDevices / ProvisionsAllDevices
//
// It first asks the kernel's codesigning configuration for an emulated UDID,
// then falls back to MobileGestalt. On a vphone600 guest the first path is
// dead: `amfi_emulate_device_udid` appears in neither the kernelcache nor TXM,
// so nothing ever publishes that key and the fallback is what runs. misagent's
// only imports that could answer are `_MGCopyAnswer` and lockdown's check-in,
// and MobileGestalt is where `UniqueDeviceID` lives.
//
// `MGCopyAnswer` is exported from libMobileGestalt, so the fallback is the one
// place a hook can stand.
//
// ## What this does
//
// When `/usr/lib/libmisfix.plist` sets `UniqueDeviceID`, a MobileGestalt query
// for that property is answered with the configured string instead of the
// guest's own. Every other query is passed through untouched. With no
// configuration the hook is inert.
//
// Point it at a device the team has already registered and that team's
// profiles install here, with no portal round trip and nothing to redo after a
// rebuild.
//
// ## How far this reaches, measured
//
// misagent, lockdownd and remoted: their main executables call MobileGestalt
// themselves, so the interpose catches them. In misagent a profile naming the
// configured device installs.
//
// installd does not benefit and no interpose can make it. Its profile check
// runs MobileInstallation → libmis → libMobileGestalt, all three inside the
// dyld shared cache, and an interpose rewrites call sites in the images dyld
// links — not the cache's own. Measured on test-26.4 (2026-09-30,
// `libmisfix[726]`): one `devicectl device install app`, `LogQueries` on, and
// the only line from installd is `MGCopyAnswer(BuildVersion) from installd`.
// No `UniqueDeviceID` query, although libmis plainly resolved one — it skipped
// every installed profile with `0xE8008012` and then returned
//
//     +[MICodeSigningVerifier _validateSignatureAndCopyInfoForURL:withOptions:error:]:
//         80: Failed to verify code signature of …/AirBuild.app : 0xe8008015
//
// The signature itself was fine; the same capture has `cdhash: <private> is
// trusted`. libmis's other route to a UDID is closed too:
// `amfi_interface_query_bootarg_state returned error Function not implemented`.
//
// ## Why this is now a convenience rather than the fix
//
// Making a profile install was one way to get an Xcode install through. It is
// no longer the way this project takes: MISFixSignature.c validates the bundle
// on its own signature with `ValidatedByProfile = 0`, and
// MISFixProfilePolicy.c lets the embedded profile fail to install without
// failing the install. An arbitrary IPA then goes in with no UDID configured
// at all, which is the point — pinning a VM to a borrowed UDID only ever
// worked for a team whose registered devices you already have.
//
// The override is kept because it is harmless, already shipped, and reachable
// from the VM window's Device ▸ Set UDID…. Setting it makes profiles install
// for real instead of being skipped, which is closer to what the device would
// have done.
//
// ## What the host sees (2026-09-30)
//
// The host learns the UDID three ways, and all three now give the configured
// one, so Xcode signs for a device the team has registered:
//
//   usbmuxd (`idevice_id`)   the USB serial string. The kernel builds it from
//                            `chip-id` and `unique-chip-id`; vphoned replaces it
//                            (`vphoned_usb.m`) and takes the device off the bus
//                            and back so the host reads it again.
//   lockdown `GetValue`      lockdownd carries this hook and asks
//                            `MGCopyAnswer(UniqueDeviceID)` itself.
//   RSD handshake            remoted carries this hook and asks through
//                            `MGCopyAnswerWithError` with the obfuscated key
//                            (`kMISFixUniqueDeviceIDObfuscatedProperty`).
//
// What stays the guest's own: TXM's and the kernel's view (AMFI, codesigning),
// which is built before any of this runs, and CoreDevice's record of a pairing
// made under the old UDID, which it keeps until that pairing is removed. The
// guest keeps one lockdown pair record per host, so switching the UDID asks
// the host to be trusted again.
//
// Matching a real iPhone's UDID in the kernel as well would mean rewriting
// `unique-chip-id`, the ECID the SHSH blob is issued against, and `chip-id` is
// fixed at 0x0000FE01 by the virtual SoC. Userspace is where this stops.

#include "MISFixConfig.h"
#include "MISFixInterpose.h"

#include <mach-o/dyld.h>

extern CFTypeRef MGCopyAnswer(CFStringRef property);
// Three arguments: the middle one is an options dictionary. Declaring two
// passed the caller's options through as the error pointer, and remoted — the
// first hooked process to call this spelling — faulted writing to it.
extern CFTypeRef MGCopyAnswerWithError(CFStringRef property, CFDictionaryRef options, uint32_t *error);

/// Log every MobileGestalt query this hook sees, and whether it answered.
///
/// Off unless the config sets `LogQueries`, because these daemons are asked a
/// lot and the log is how a person watches an install. It exists because the
/// interesting failure is *silence*: the override reaches misagent and a
/// profile installs, but installd then refuses the same app with
/// `0xE8008015`, and the two explanations — installd asking and getting the
/// wrong answer, versus installd never asking through this symbol at all —
/// look identical from outside.
///
/// It has now told us which. Each line names the caller's image, and installd
/// produced exactly one, `MGCopyAnswer(BuildVersion) from installd`: the main
/// executable's own call and nothing else. The header's "How far this reaches"
/// has the rest. The instrument stays because the answer is a property of this
/// cache and this dyld, not a law, and one capture re-checks it.
static void vpLogQuery(CFStringRef property, int answered, const char *caller) {
    char name[128];
    if (property == NULL
        || !CFStringGetCString(property, name, sizeof(name), kCFStringEncodingUTF8))
    {
        return;
    }
    MISFixLog(
        "MGCopyAnswer(%s) from %s %s",
        name,
        caller,
        answered ? "-> override" : "passed through"
    );
}

/// Say, once, that this dylib is in this process.
///
/// The positive control the diagnosis needs. Without it, "installd logged no
/// MGCopyAnswer" has two readings that look the same — the call never came
/// through the interposed symbol, or the hook was not in the process at all —
/// and they call for opposite fixes. With it, the pair of lines is decisive:
/// this one and no query line means the call is bypassing the interpose.
__attribute__((constructor)) static void vpAnnounce(void) {
    char path[4096];
    uint32_t size = sizeof(path);
    MISFixLog("loaded into %s", _NSGetExecutablePath(path, &size) == 0 ? path : "<unknown>");
}

/// MobileGestalt's key for the UDID. A plain string, not the SDK constant:
/// there is no public header, and this is the literal misagent carries.
#define kMISFixUniqueDeviceIDProperty CFSTR("UniqueDeviceID")

/// The same key as MobileGestalt also accepts it: base64 of
/// MD5("MGCopyAnswer" + key), unpadded. remoted asks this way when it builds the
/// RSD handshake that CoreDevice and Xcode read the UDID from.
#define kMISFixUniqueDeviceIDObfuscatedProperty CFSTR("re6Zb+zwFKJNlkQTUeT+/w")

/// The configured answer for `property`, already retained for the caller, or
/// NULL to let MobileGestalt answer.
static CFTypeRef vpOverrideFor(CFStringRef property) {
    if (property == NULL || CFGetTypeID(property) != CFStringGetTypeID())
        return NULL;
    if (!CFEqual(property, kMISFixUniqueDeviceIDProperty)
        && !CFEqual(property, kMISFixUniqueDeviceIDObfuscatedProperty))
    {
        return NULL;
    }

    CFStringRef configured = MISFixCopyConfiguredDeviceIdentifier();
    if (configured == NULL)
        return NULL;

    // MGCopyAnswer returns +1; the caller releases what it gets.
    return CFStringCreateCopy(kCFAllocatorDefault, configured);
}

static CFTypeRef vpMGCopyAnswer(CFStringRef property) {
    const char *caller = MISFixCaller();
    CFTypeRef override = vpOverrideFor(property);
    vpLogQuery(property, override != NULL, caller);
    return override != NULL ? override : MGCopyAnswer(property);
}

static CFTypeRef vpMGCopyAnswerWithError(CFStringRef property, CFDictionaryRef options, uint32_t *error) {
    const char *caller = MISFixCaller();
    CFTypeRef override = vpOverrideFor(property);
    vpLogQuery(property, override != NULL, caller);
    if (override == NULL)
        return MGCopyAnswerWithError(property, options, error);
    if (error != NULL)
        *error = 0;
    return override;
}

// Both spellings are replaced. misagent imports only the plain one;
// remoted asks for `UniqueDeviceID` through the variant.
MISFIX_INTERPOSE(vpMGCopyAnswer, MGCopyAnswer);
MISFIX_INTERPOSE(vpMGCopyAnswerWithError, MGCopyAnswerWithError);
