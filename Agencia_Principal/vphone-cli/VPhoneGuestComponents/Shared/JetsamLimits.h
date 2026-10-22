#ifndef VPHONE_JETSAM_LIMITS_H
#define VPHONE_JETSAM_LIMITS_H

#include "InjectionEnvironment.h"
#include <spawn.h>
#include <string.h>
#include <unistd.h>

// Dopamine's spawn hooks, in launchd and in every injected process, multiply
// the jetsam memory limits a spawn carries by its jetsamMultiplier setting,
// 3 unless the user changed it (BaseBin/systemhook/src/common/common.c,
// spawn_exec_hook_common). They leave a limit of -1 (none) alone and skip
// what Dopamine does not inject: its process blacklist, a spawn with
// _SafeMode=1 or _MSSafeMode=1, a DriverKit driver, and every spawn while the
// hook dylib is missing. vphone does the same while a bootstrap is installed.
#define VP_JETSAM_MULTIPLIER 3

// psa_memlimit_active, followed by psa_memlimit_inactive, in xnu's
// struct _posix_spawnattr (bsd/sys/spawn_internal.h, xnu-12377). Neither has
// a getter in libsystem_kernel; Dopamine writes the same offsets.
#define VP_SPAWNATTR_MEMLIMITS 0x48
#define VP_SPAWN_PROC_TYPE_DRIVER 0x700

int posix_spawnattr_getprocesstype_np(const posix_spawnattr_t *__restrict, int *__restrict);

typedef struct {
    int *limits;
    int original[2];
} VPJetsamLimits;

// Multiplies the limits in `attributes` in place for the spawn of `path`, and
// returns what vpRestoreJetsamLimits needs to put the caller's values back.
static VPJetsamLimits vpRaiseJetsamLimits(const char *root, const char *path,
                                          const posix_spawnattr_t *attributes, char *const envp[]) {
    static const char *const blacklist[] = {
        "/System/Library/Frameworks/GSS.framework/Helpers/GSSCred",
        "/System/Library/PrivateFrameworks/DataAccess.framework/Support/dataaccessd",
        "/System/Library/PrivateFrameworks/IDSBlastDoorSupport.framework/XPCServices/IDSBlastDoorService.xpc/"
        "IDSBlastDoorService",
        "/System/Library/PrivateFrameworks/MessagesBlastDoorSupport.framework/XPCServices/"
        "MessagesBlastDoorService.xpc/MessagesBlastDoorService",
    };
    VPJetsamLimits raised = {0};
    if (!root || !*root || !path || !attributes || !*attributes)
        return raised;
    for (size_t i = 0; i < sizeof(blacklist) / sizeof(blacklist[0]); i++) {
        if (strcmp(path, blacklist[i]) == 0)
            return raised;
    }
    if (vpEnvIsOne(envp, "_SafeMode") || vpEnvIsOne(envp, "_MSSafeMode"))
        return raised;
    int type = 0;
    if (posix_spawnattr_getprocesstype_np(attributes, &type) == 0 && type == VP_SPAWN_PROC_TYPE_DRIVER)
        return raised;
    if (access(VP_SYSTEM_HOOK, F_OK) != 0)
        return raised;
    raised.limits = (int *)((char *)*attributes + VP_SPAWNATTR_MEMLIMITS);
    for (size_t i = 0; i < 2; i++) {
        raised.original[i] = raised.limits[i];
        if (raised.limits[i] != -1)
            raised.limits[i] *= VP_JETSAM_MULTIPLIER;
    }
    return raised;
}

static void vpRestoreJetsamLimits(const VPJetsamLimits *raised) {
    if (raised->limits)
        memcpy(raised->limits, raised->original, sizeof(raised->original));
}

#endif
