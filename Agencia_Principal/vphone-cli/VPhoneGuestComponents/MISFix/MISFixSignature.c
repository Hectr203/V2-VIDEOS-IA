// MISFixSignature.c — widen MIS's idea of an acceptable signature.
//
// A guest restored by this project runs unsigned code happily: the kernel
// patches (`amfi_trustcache`, `jb.post_validation`, `jb.amfi_execve`) admit it,
// lsd registers it, and SpringBoard launches it. An app pushed in through
// vphoned's `apps.install` proves the whole chain — it is signed with nothing
// but the project's own ldid-shaped signature and it reaches the foreground.
//
// Everything except installd. `xcrun devicectl device install app` stops at a
// single userspace gate:
//
//     +[MICodeSigningVerifier _validateSignatureAndCopyInfoForURL:withOptions:error:]
//         → MISValidateSignatureAndCopyInfo   (/usr/lib/libmis.dylib)
//
//     unsigned                  → 0xE800801C  No code signature found.
//     ldid, no CMS blob         → 0xE800801C
//     codesign --sign - (adhoc) → 0xE8008014  The executable contains an invalid signature.
//
// so Xcode cannot install anything it did not sign with a real Apple leaf.
//
// ## What this does
//
// MIS already knows how to accept an ad-hoc signature; installd simply never
// asks it to. The options dictionary carries a documented-by-string key for
// exactly that, and setting it is the whole fix. Measured in the guest, on a
// bundle signed with `codesign --sign -`:
//
//     no options                                     → 0xE8008014
//     AllowAdHocSigning                              → 0  ✅
//     AllowAdHocSigning + ValidateSignatureOnly      → 0
//     AllowAdHocSigning + SkipProfileIdentifierPolicy→ 0
//     ValidateSignatureOnly                          → 0xE8008014
//     TrustCacheOnly                                 → 0xE8008014
//
// and the info dictionary MIS returns on success is complete — `CdHash`,
// `Entitlements`, `SigningID`, `SignerType`, `SignatureVersion`,
// `IsNativeForPlatform`, `ValidatedByProfile` — so nothing here has to
// synthesise a reply. That matters: installd reads those keys, and a hook that
// faked success without them would break the install further down.
//
// So the hook adds keys to the options and calls through. On anything MIS
// would have accepted anyway the behaviour is bit for bit unchanged, because
// the keys only widen what counts as acceptable.
//
// ## Why this is a detour and not an interpose
//
// It used to be an interpose, and that was measured wrong on 2026-09-30. A
// `__DATA,__interpose` replacement is applied to *call sites*, and every call
// site that matters here is inside the dyld shared cache:
//
//     MobileInstallation.framework  →  libmis.dylib        (cache to cache)
//
// Neither dyld's linking of this dylib as a weak dependency nor
// `DYLD_INSERT_LIBRARIES` rewrites that. With `LogQueries` on and this file's
// log made unconditional, a whole `devicectl device install app` produced not
// one line from installd, while `MICodeSigningVerifier` ran to its line 80 and
// failed. The options were never widened, in any install, ever.
//
// A detour rewrites the callee instead, so there is nothing to miss: one copy
// of the function, one jump at its top, every caller redirected. See
// MISFixDetour.h for what that costs and what it refuses.
//
// Two details of the target, both of which the detour has to respect.
//
// `MISValidateSignatureAndCopyInfo` is a short thunk in front of
// `…WithProgress`, where libmis's body actually lives, so it is *shorter than
// the four-word jump* and `MISFixDetour` declines it with
// `MISFixDetourTooShort`. That is the expected outcome, not a failure: the
// thunk branches into the function that is hooked, so its callers are covered
// anyway. Both are attempted so the log says which one took.
//
// The address cannot come from `dlsym`. dyld applies interposing to it, so a
// hooked symbol resolves to our own replacement — measured even through a
// handle on libmis itself. Taking `&MISValidateSignatureAndCopyInfoWithProgress`
// here uses this image's own import, which dyld leaves alone.
//
// ## What this deliberately does not do
//
// An unsigned binary still fails, with `0xE800801C`, and that is left alone.
// Everything past installd needs the cdhash that only a signature carries, and
// `codesign --sign -` (Xcode's "Sign to Run Locally") costs nothing and
// supplies one. Forging a reply for a bundle with no signature at all would
// mean inventing a cdhash the kernel never agreed to.
//
// The profile half of an Xcode install is not here either; it is
// MISFixProfilePolicy.c.

#include "MISFixConfig.h"
#include "MISFixDetour.h"

#include <CoreFoundation/CoreFoundation.h>
#include <stdlib.h>

// libmis's own option keys, taken from the cache's string table rather than
// from a header — libmis.tbd exports the `kMISValidationOption*` symbols but
// the SDK declares none of them.
#define kMISValidationOptionAllowAdHocSigning CFSTR("AllowAdHocSigning")
#define kMISValidationOptionRespectUppTrustAndAuthorization CFSTR("RespectUppTrustAndAuthorization")
#define kMISValidationOptionSkipProfileIdentifierPolicy CFSTR("SkipProfileIdentifierPolicy")

// The first argument is a path string, not a URL. Handing MIS an NSURL aborts
// the process inside libmis with `-[NSURL length]: unrecognized selector`,
// which is how this was pinned down.
typedef CFStringRef MISPath;

typedef int (*MISValidate)(MISPath path, CFDictionaryRef options, CFDictionaryRef *info);
typedef int (*MISValidateWithProgress)(
    MISPath path,
    CFDictionaryRef options,
    CFDictionaryRef *info,
    void *progress
);

extern int MISValidateSignatureAndCopyInfo(MISPath path, CFDictionaryRef options, CFDictionaryRef *info);
extern int MISValidateSignatureAndCopyInfoWithProgress(
    MISPath path,
    CFDictionaryRef options,
    CFDictionaryRef *info,
    void *progress
);

static MISValidate vpOriginalValidate;
static MISValidateWithProgress vpOriginalValidateWithProgress;

/// The caller's options, widened. Never returns NULL for a NULL input: MIS is
/// called with an options dictionary either way.
///
/// Three keys go in.
///
/// `AllowAdHocSigning` is the signature half described above.
///
/// `SkipProfileIdentifierPolicy` stops MIS insisting that a profile's
/// application-identifier match the bundle's. A profile that names a different
/// app — or an app whose profile never installed, which is the ordinary case
/// for an IPA built for someone else's team — is then not a reason to refuse a
/// signature that is otherwise fine. Measured to leave an accepted bundle
/// accepted.
///
/// `RespectUppTrustAndAuthorization = false` is the online-authorization half,
/// and it replaces a patch that used to edit the shared cache. libmis reaches
/// `checkTrustAndAuthorization` — the only producer of `0xE8008026`, "missing
/// trust and/or authorization" — through a branch gated on precisely this
/// option, so turning it off means the check is never called and the failure
/// cannot arise. A hacktivated guest has no activation record and so can never
/// satisfy that check; `mis_trust_auth` used to force the function to return
/// success by rewriting its prologue in the cache, which is what leaves a 27.0
/// guest unable to boot (issue #532).
///
/// Steering rather than forcing also matters for correctness, not just for the
/// cache: on the failure path libmis returns without ever writing the `info`
/// out-parameter, so a hook that rewrote the return code to 0 would hand its
/// caller success with no `CdHash` and no `Entitlements`. Declining the check
/// makes the ordinary success path run and fill the dictionary for real.
///
/// The option parser writes a flag's slot only when the key is present, so an
/// explicit value always beats the defaults `UnauthoritativeLaunch` installs —
/// and nothing else in the shared cache passes these keys, so there is no
/// caller's own value to override.
static CFDictionaryRef vpWidenedOptions(CFDictionaryRef options) {
    CFMutableDictionaryRef widened =
        options != NULL
            ? CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, options)
            : CFDictionaryCreateMutable(
                  kCFAllocatorDefault,
                  3,
                  &kCFTypeDictionaryKeyCallBacks,
                  &kCFTypeDictionaryValueCallBacks
              );
    if (widened == NULL)
        return NULL;
    CFDictionarySetValue(widened, kMISValidationOptionAllowAdHocSigning, kCFBooleanTrue);
    CFDictionarySetValue(
        widened,
        kMISValidationOptionSkipProfileIdentifierPolicy,
        kCFBooleanTrue
    );
    CFDictionarySetValue(
        widened,
        kMISValidationOptionRespectUppTrustAndAuthorization,
        kCFBooleanFalse
    );
    return widened;
}

/// Log one validation, under `LogQueries`.
///
/// Never returns early. A first run logged nothing here from installd, which
/// was read as "the hook was not reached" — but a `path` this could not turn
/// into a C string would have produced exactly the same silence. The line says
/// what the argument was when it is not a string, so an absent line means one
/// thing only.
static void vpLogValidation(MISPath path, int result) {
    char buffer[1024];
    if (path == NULL) {
        MISFixLog("MISValidateSignature(NULL) -> 0x%x", (unsigned)result);
        return;
    }
    if (CFGetTypeID(path) != CFStringGetTypeID()
        || !CFStringGetCString(path, buffer, sizeof(buffer), kCFStringEncodingUTF8))
    {
        MISFixLog(
            "MISValidateSignature(<non-string %lu>) -> 0x%x",
            (unsigned long)CFGetTypeID(path),
            (unsigned)result
        );
        return;
    }
    MISFixLog("MISValidateSignature(%s) -> 0x%x", buffer, (unsigned)result);
}

/// One line naming what MIS put in the info dictionary, under `LogQueries`.
///
/// This is the instrument for the gates *above* MIS. `MICodeSigningVerifier`
/// accepts MIS's answer and then wants more from it — a signer identity, an
/// identifier that matches the bundle — and which key it is reading is not
/// visible from the failure it reports. Naming the keys, and the short values,
/// is what turns that into a readable question.
static void vpLogInfo(CFDictionaryRef info) {
    if (info == NULL || CFGetTypeID(info) != CFDictionaryGetTypeID())
        return;
    CFIndex count = CFDictionaryGetCount(info);
    if (count <= 0) {
        MISFixLog("  info: empty");
        return;
    }
    const void **keys = calloc((size_t)count, sizeof(void *));
    const void **values = calloc((size_t)count, sizeof(void *));
    if (keys == NULL || values == NULL) {
        free(keys);
        free(values);
        return;
    }
    CFDictionaryGetKeysAndValues(info, keys, values);
    for (CFIndex index = 0; index < count; index += 1) {
        CFStringRef key = (CFStringRef)keys[index];
        char name[128];
        if (key == NULL || CFGetTypeID(key) != CFStringGetTypeID()
            || !CFStringGetCString(key, name, sizeof(name), kCFStringEncodingUTF8))
        {
            continue;
        }
        CFTypeRef value = values[index];
        CFTypeID kind = value != NULL ? CFGetTypeID(value) : 0;
        char shown[160] = "<…>";
        if (value == NULL) {
            snprintf(shown, sizeof(shown), "<null>");
        } else if (kind == CFStringGetTypeID()) {
            CFStringGetCString((CFStringRef)value, shown, sizeof(shown), kCFStringEncodingUTF8);
        } else if (kind == CFBooleanGetTypeID()) {
            snprintf(shown, sizeof(shown), CFBooleanGetValue((CFBooleanRef)value) ? "true" : "false");
        } else if (kind == CFNumberGetTypeID()) {
            long long number = 0;
            CFNumberGetValue((CFNumberRef)value, kCFNumberLongLongType, &number);
            snprintf(shown, sizeof(shown), "%lld", number);
        } else if (kind == CFDataGetTypeID()) {
            snprintf(shown, sizeof(shown), "<%ld bytes>",
                     (long)CFDataGetLength((CFDataRef)value));
        } else if (kind == CFDictionaryGetTypeID()) {
            snprintf(shown, sizeof(shown), "<%ld entries>",
                     (long)CFDictionaryGetCount((CFDictionaryRef)value));
        }
        MISFixLog("  info[%s] = %s", name, shown);
    }
    free(keys);
    free(values);
}

static int vpValidate(MISPath path, CFDictionaryRef options, CFDictionaryRef *info) {
    CFDictionaryRef widened = vpWidenedOptions(options);
    // Out of memory: pass the caller's own options through rather than fail.
    if (widened == NULL)
        return vpOriginalValidate(path, options, info);
    int result = vpOriginalValidate(path, widened, info);
    CFRelease(widened);
    vpLogValidation(path, result);
    if (result == 0 && info != NULL)
        vpLogInfo(*info);
    return result;
}

static int vpValidateWithProgress(
    MISPath path,
    CFDictionaryRef options,
    CFDictionaryRef *info,
    void *progress
) {
    CFDictionaryRef widened = vpWidenedOptions(options);
    if (widened == NULL)
        return vpOriginalValidateWithProgress(path, options, info, progress);
    int result = vpOriginalValidateWithProgress(path, widened, info, progress);
    CFRelease(widened);
    vpLogValidation(path, result);
    if (result == 0 && info != NULL)
        vpLogInfo(*info);
    return result;
}

/// Hook both entry points before the daemon serves anything.
///
/// The `…WithProgress` one is the body and is the one that has to take. The
/// plain one is a thunk in front of it and is expected to come back
/// `MISFixDetourTooShort`; it is attempted anyway, because "expected" is a
/// property of one libmis build and the log is how the next one tells us it
/// changed.
__attribute__((constructor)) static void vpInstallSignatureHooks(void) {
    if (MISFixProcessOnlyNeedsIdentity())
        return;
    MISFixDetourResult body = MISFixDetour(
        "MISValidateSignatureAndCopyInfoWithProgress",
        (void *)&MISValidateSignatureAndCopyInfoWithProgress,
        (void *)&vpValidateWithProgress,
        (void **)&vpOriginalValidateWithProgress
    );
    if (body != MISFixDetourOK) {
        MISFixNote("MISValidateSignatureAndCopyInfoWithProgress not hooked: %s",
                   MISFixDetourDescribe(body));
    }

    MISFixDetourResult thunk = MISFixDetour(
        "MISValidateSignatureAndCopyInfo",
        (void *)&MISValidateSignatureAndCopyInfo,
        (void *)&vpValidate,
        (void **)&vpOriginalValidate
    );
    if (thunk != MISFixDetourOK) {
        MISFixLog("MISValidateSignatureAndCopyInfo not hooked: %s",
                  MISFixDetourDescribe(thunk));
    }
}
