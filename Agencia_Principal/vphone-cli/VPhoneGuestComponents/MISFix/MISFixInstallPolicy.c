// MISFixInstallPolicy.c — the two places installd refuses an app for a reason
// that does not apply to this guest.
//
// MISFixSignature.c widens what MIS itself will accept. This file is what sits
// above MIS: MobileInstallation's own policy, which asks for things a research
// VM cannot have and then treats their absence as a failed install.
//
// Both hooks call the real implementation first and only override a refusal,
// so on anything that would have installed anyway the behaviour is unchanged.
//
// ## The embedded profile
//
//     Failed to install embedded profile for plus.yellow.AirBuild : 0xE8008012
//       (This provisioning profile cannot be installed on this device.)
//       -[MIInstallableBundle _installEmbeddedProfilesWithError:]
//
// `0xE8008012` is correct and always will be. A profile names the devices it
// covers, in `ProvisionedDevices`, and a VM's UDID is in nobody's list. Xcode
// papers over that for a *free* personal team by registering whatever device
// is plugged in; for a paid team there is no auto-registration, and the VM
// would have to be added to the account by hand and again after every
// `vm create`.
//
// A profile does two things — it vouches that a signing identity may run on
// this device, and it carries the entitlements the app may claim — and neither
// is load-bearing here. The kernel patches admit the code whatever signed it,
// and MIS has already validated the bundle on its own signature with
// `ValidatedByProfile = 0`. So a profile that cannot install is noted and
// skipped; one that can install still does, unchanged.
//
// ## The signer identity
//
//     Failed to extract signer identity from <MIExecutableBundle …>
//       -[MICodeSigningVerifier performValidationWithError:]  line 424
//
// This is the gate behind the gate, and it is why widening MIS's options is
// not by itself enough. MIS accepts an ad-hoc signature and fills its info
// dictionary — `CdHash`, `Entitlements`, `SigningID` — but MobileInstallation
// then wants a *signer*: the leaf certificate out of a CMS blob, which an
// ad-hoc signature does not have and never will, because the whole point of
// ad-hoc is that nobody signed it.
//
// `MICodeSigningVerifier` already knows what to do about that. It carries
// `allowAdhocSigning` as a settable property, exactly like the MIS option, and
// installd never turns it on. Forcing the getter is the whole fix, and it is
// the class's own idea of the answer rather than an override of a decision it
// made: with it on, the real `performValidationWithError:` succeeds and fills
// `signingInfo` for real.
//
// That matters, and the alternative is what proved it. Forcing
// `performValidationWithError:` to return `YES` after it failed got no further
// — the verifier had bailed before storing anything, so its caller read a nil
// signing identifier and refused with
//
//     -[MIExecutableBundle codeSigningInfoByValidatingResources:…]: 1306:
//         Code signing identifier ((null)) does not match bundle identifier (…)
//
// A refusal can be allowed through; an answer that was never computed cannot
// be invented. Only the first of those is done here.
//
// Measured on test-26.4 (2026-09-30): a `codesign --sign -` bundle with no
// certificate and no provisioning profile installs through
// `devicectl device install app` and launches.
//
// What is *not* covered, deliberately: a bundle with no signature at all
// still fails with `0xE800801C`, and an app missing the
// `application-identifier` entitlement still fails. Both are real absences
// rather than policy, and everything downstream needs what they are missing.
// Unsigned bundles reach the guest through vphoned's `apps.install`, which
// re-signs in the container and never involves installd.
//
// ## Why a swizzle and not a detour
//
// These are Objective-C methods in MobileInstallation, and an Objective-C
// method list is *data*. Replacing an implementation through the runtime
// reaches every caller, in the shared cache or out of it, without making a
// single page of cache text writable. Where that is available it is strictly
// better than MISFixDetour.h, and here it is available.
//
// The classes are looked up rather than linked, and a version that does not
// have one leaves that hook inert with a line in the log. That is deliberate:
// these are private methods on private classes, and the guest is expected to
// be a version this project has not seen yet.

#include "MISFixConfig.h"

#include <dlfcn.h>
#include <objc/objc.h>
#include <objc/runtime.h>
#include <stdlib.h>

/// MobileInstallation's install name, for the case where a class is not
/// registered yet. Our constructor runs among the inserted libraries, ahead of
/// most of the process; every image present at launch has had its classes
/// realised by then, but a framework installd only dlopens later would not be
/// there at all.
#define kMISFixMobileInstallationPath \
    "/System/Library/PrivateFrameworks/MobileInstallation.framework/MobileInstallation"

/// A `BOOL`-returning method whose only argument is an `NSError **`
/// out-parameter. Two of the three hooks have this shape.
typedef BOOL (*MISFixCheckIMP)(id self, SEL selector, void *error);

/// Print a class's own methods and ivars.
///
/// Called only when a selector this file expects has gone, which is the one
/// moment the list is worth its few hundred lines: it says what the method was
/// renamed to, on the guest, without disassembling the shared cache. The
/// runtime knows, and asking it is cheaper and more honest.
static void vpDescribeClass(Class found, const char *className) {
    unsigned count = 0;
    Method *methods = class_copyMethodList(found, &count);
    for (unsigned index = 0; index < count; index += 1)
        MISFixNote("  -[%s %s]", className, sel_getName(method_getName(methods[index])));
    free(methods);

    count = 0;
    Ivar *ivars = class_copyIvarList(found, &count);
    for (unsigned index = 0; index < count; index += 1) {
        const char *encoding = ivar_getTypeEncoding(ivars[index]);
        MISFixNote("  %s ivar %s : %s", className, ivar_getName(ivars[index]),
                   encoding != NULL ? encoding : "?");
    }
    free(ivars);
}

/// Replace `className`'s `-selectorName` with `replacement` and return the
/// implementation it had, or NULL.
///
/// NULL and a line in the log is the expected outcome on an OS version that
/// renamed the method, and every caller is written so that means "this hook is
/// inert" rather than anything worse.
static IMP vpSwizzle(const char *className, const char *selectorName, IMP replacement) {
    Class found = objc_getClass(className);
    if (found == NULL) {
        if (dlopen(kMISFixMobileInstallationPath, RTLD_LAZY) != NULL)
            found = objc_getClass(className);
    }
    if (found == NULL) {
        MISFixNote("%s is not in this process", className);
        return NULL;
    }
    Method method = class_getInstanceMethod(found, sel_registerName(selectorName));
    if (method == NULL) {
        MISFixNote("%s has no -%s; its interface follows", className, selectorName);
        vpDescribeClass(found, className);
        return NULL;
    }
    IMP original = method_setImplementation(method, replacement);
    MISFixNote("swizzled -[%s %s]", className, selectorName);
    return original;
}

/// Clear an `NSError **` the failing implementation wrote.
///
/// A caller handed `YES` alongside a populated `NSError *` is a shape no
/// ordinary method produces, and installd does read the out-parameter. The
/// error object itself is left to the autorelease pool it came from.
static void vpClearError(void *error) {
    if (error != NULL)
        *(void **)error = NULL;
}

// MARK: - The embedded profile

static MISFixCheckIMP vpOriginalInstallProfiles;

static BOOL vpInstallEmbeddedProfiles(id self, SEL selector, void *error) {
    if (vpOriginalInstallProfiles(self, selector, error))
        return YES;
    vpClearError(error);
    MISFixNote("embedded profile refused; installing without one");
    return YES;
}

// MARK: - The signer identity

/// The verifier's own switch for an ad-hoc signature, forced on.
///
/// `MICodeSigningVerifier` carries `allowAdhocSigning` as a settable property
/// and installd leaves it off, which is the same shape as the MIS option:
/// the capability is there and nothing asks for it. Turning it on in the
/// getter is the smallest possible change and it is the code's own idea of
/// what to do, not an override of a decision it made.
static BOOL vpAllowAdhocSigning(id self, SEL selector) {
    (void)self;
    (void)selector;
    return YES;
}

/// installd only. The same dylib is inserted into misagent and SpringBoard, and
/// neither runs an install; `vpSwizzle` would dlopen MobileInstallation into
/// them just to find a class they never use.
__attribute__((constructor)) static void vpInstallPolicyHooks(void) {
    if (!MISFixProcessIs("installd"))
        return;
    vpOriginalInstallProfiles = (MISFixCheckIMP)vpSwizzle(
        "MIInstallableBundle",
        "_installEmbeddedProfilesWithError:",
        (IMP)&vpInstallEmbeddedProfiles
    );
    vpSwizzle("MICodeSigningVerifier", "allowAdhocSigning", (IMP)&vpAllowAdhocSigning);
}
