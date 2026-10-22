#pragma once

// The hybrid kernel also rejects CoreDevice's installation proxy looking up
// UserManager. Keep this exception scoped to the exact executable and signing
// identity, with the requesting audit token checked by the kernel to reject
// stale/reused PIDs. See Research/Guest/ios27_xcode_persona_lookup.md.
#define VP_PERSONA_MARKER "/usr/lib/vphone-installcoordination-persona-lookup"
#define VP_PERSONA_SERVICE "com.apple.mobile.usermanagerd.xpc"
#define VP_INSTALL_PROXY "/System/Library/PrivateFrameworks/InstallCoordination.framework/Support/installcoordination_proxy"
extern int proc_pidpath(int pid, void *buffer, uint32_t buffersize);
extern int csops_audittoken(pid_t pid, unsigned int operations, void *buffer,
                           size_t size, vp_audit_token_t *token);

static int vpInstallProxyPersonaAllowed(vp_audit_token_t token, const char *operation,
                                        unsigned int filter, const void *name) {
    // IDA: launchd sub_100037028 uses name filters 2, 3 and 12 for lookup.
    if (!operation || (filter != 2 && filter != 3 && filter != 12) || !name ||
        strcmp(operation, "mach-lookup") || strcmp(name, VP_PERSONA_SERVICE))
        return 0;
    struct stat marker;
    if (lstat(VP_PERSONA_MARKER, &marker) || !S_ISREG(marker.st_mode) ||
        marker.st_uid != 0 || (marker.st_mode & 022))
        return 0;
    pid_t pid = (pid_t)token.val[5];
    char path[PATH_MAX] = {0};
    if (pid <= 0 || proc_pidpath(pid, path, sizeof(path)) <= 0 || strcmp(path, VP_INSTALL_PROXY))
        return 0;
    // CS_OPS_IDENTITY returns an 8-byte blob header followed by a NUL string.
    unsigned char identity[256] = {0};
    if (csops_audittoken(pid, 11, identity, sizeof(identity), &token))
        return 0;
    return strcmp((const char *)identity + 8, "com.apple.installcoordination_proxy") == 0;
}
