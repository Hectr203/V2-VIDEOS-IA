// libhapticsfix.c — the haptics hardware the guest's identity promises does
// not exist, and CoreHaptics answers that with an exception instead of nil.
//
// Virtualization.framework exposes no haptic device, on any base. A real
// device without one — every iPad that is not a Pro — gets nil from
// `CHHapticEngine`'s initialisers, UIKit carries on without feedback, and
// that is the whole story. A guest reporting an iPad Pro model inverts it:
// the OS expects the haptic stack to exist, so with the driver missing the
// initialiser does not fail, it *raises* — `Haptic_RaiseException` out of
// `-[CHHapticEngine initWithAudioSession:sessionIsShared:options:error:]` —
// and the unwind out of UIKit's feedback queue ends in SpringBoard dying:
//
//   EXC_BAD_ACCESS (SIGBUS), KERN_PROTECTION_FAILURE — iPad16,1 26.6.2
//   (23G90), thread com.apple.UIKit.FeedbackCoreHapticsEngineInternal,
//   -[_UIFeedbackCoreHapticsIgnoreCaptureHapticsOnlyEngine
//   _internal_createCoreHapticsEngine] -> objc_exception_throw ->
//   _Unwind_RaiseException, resumed at an address inside a no-access
//   Memory Tag 255 region, 4h14m after launch on the first feedback event.
//
// This hook gives the guest the no-hardware answer before CoreHaptics can
// raise: every `CHHapticEngine` initialiser returns nil, which is what the
// same framework answers on a device with no haptics. No UIKit error path
// dereferences past messaging nil, so feedback is simply absent, as on such
// devices.
//
// SystemHook loads this in SpringBoard only (`vpIsSpringBoard`): the one
// UIKit process measured creating the haptics-only engine without first
// asking CoreHaptics whether the hardware exists. Apps follow the documented
// path — `CHHapticEngine.capabilitiesForHardware`, which already answers no
// on the guest — so they never reach an initialiser.

#include <ctype.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <objc/runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define VP_CORE_HAPTICS "/System/Library/Frameworks/CoreHaptics.framework/CoreHaptics"

// Every initialiser funnels here whatever its arguments: they arrive in
// registers this never touches, and IMP is variadic, so a call with extras
// lands the same way it lands in any stub. Only the return matters — nil,
// the framework's own answer on hardware without haptics.
static id vpEngineUnsupported(id self, SEL selector) {
    return nil;
}

// `init`, or `init` followed by an uppercase selector part — the shape of an
// initialiser and not of, say, an `initialise…` helper.
static int vpIsInitializer(const char *name) {
    return strcmp(name, "init") == 0 ||
           (strncmp(name, "init", 4) == 0 && isupper((unsigned char)name[4]) != 0);
}

__attribute__((constructor)) static void vpInstallHapticsFix(void) {
    // CoreHaptics is not loaded when this runs — the spawn hooks start long
    // before UIKit reads anything — and the class must be in the runtime
    // before UIKit asks for an engine. Loading it here is what puts it
    // there; RTLD_LAZY keeps the cost to the framework's own initialisers.
    dlopen(VP_CORE_HAPTICS, RTLD_LAZY | RTLD_LOCAL);
    Class engine = objc_getClass("CHHapticEngine");
    if (!engine)
        return;

    unsigned int count = 0;
    Method *methods = class_copyMethodList(engine, &count);
    if (!methods)
        return;
    unsigned int replaced = 0;
    for (unsigned int index = 0; index < count; index++) {
        if (!vpIsInitializer(sel_getName(method_getName(methods[index]))))
            continue;
        method_setImplementation(methods[index], (IMP)vpEngineUnsupported);
        replaced++;
    }
    free(methods);

    // SpringBoard runs as mobile and owns this directory; the mode keeps a
    // root writer of the same log from silencing later ones, as in SystemHook.
    int fd = open("/var/mobile/Library/Caches/vphone-hapticsfix.log",
                  O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC, 0666);
    if (fd < 0)
        return;
    fchmod(fd, 0666);
    dprintf(fd, "pid=%d CHHapticEngine initialisers returning nil: %u of %u\n",
            getpid(), replaced, count);
    close(fd);
}

int vphone_hapticsfix_version(void) { return 1; }
