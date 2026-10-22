// The status, allow, and off verbs.
#include "Escalator.h"

#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <sys/sysctl.h>
#include <unistd.h>

// --------------------------------------------------------------------------
// reporting
// --------------------------------------------------------------------------

static int sysctl_int(const char *name) {
    int value = 0;
    size_t len = sizeof(value);
    return sysctlbyname(name, &value, &len, NULL, 0) == 0 ? value : -1;
}

void report(const char *self_path) {
    printf("host\n");
    printf(
        "  vm.cs_system_enforcement   %d%s\n",
        sysctl_int("vm.cs_system_enforcement"),
        sysctl_int("vm.cs_system_enforcement") == 1 ? "  (code patching is fatal here)" : ""
    );
    printf("  preference file            %s\n",
           access(PREFS_PATH, R_OK) == 0 ? PREFS_PATH : PREFS_PATH " (absent)");

    CFStringRef stock = stock_requirement();
    char buf[4096];
    if (CFStringGetCString(stock, buf, sizeof(buf), kCFStringEncodingUTF8))
        printf("  stock requirement          %s\n", buf);
    CFRelease(stock);

    if (!attach_amfid(self_path)) return;
    printf("amfid\n");
    printf("  pid                        %d\n", g_amfid);
    printf("  singleton slot             %#llx  (shared cache, same in every process)\n",
           (unsigned long long)singleton_slot());

    mach_vm_address_t mgr = amfid_manager(self_path);
    if (!mgr) return;
    uint8_t internal = 0, unsafe_linking = 0;
    uintptr_t restricted = 0;
    read_amfid(mgr + ivar_offset("_isRunningInternalBuild"), &internal, 1);
    read_amfid(mgr + ivar_offset("_allowUnsafeDynamicLinking"), &unsafe_linking, 1);
    read_amfid(mgr + ivar_offset("_restrictedRequirement"), &restricted, sizeof(restricted));
    printf("  %s          %#llx\n", MANAGER_CLASS, (unsigned long long)mgr);
    printf("  _isRunningInternalBuild    %u%s\n", internal, internal ? "  (preference honoured)" : "");
    printf("  _allowUnsafeDynamicLinking %u\n", unsafe_linking);
    printf(
        "  _restrictedRequirement     %#lx%s\n",
        (unsigned long)restricted,
        restricted ? "" : "  (nothing would be allowed)"
    );
}

// --------------------------------------------------------------------------

int cmd_allow(const char *self_path, int count, char **paths, int hold_seconds) {
    if (update_allow_preferences(count, paths)) return 1;
    if (!attach_amfid(self_path)) return 1;
    mach_vm_address_t mgr = amfid_manager(self_path);
    if (!mgr) return 1;

    // amfid is already holding the stock requirement, so "non-NULL" proves
    // nothing. Adoption is the pointer changing: the preference path releases
    // the old SecRequirementRef and stores a freshly built one.
    ptrdiff_t req_off = ivar_offset("_restrictedRequirement");
    uintptr_t before = 0;
    if (!read_amfid(mgr + req_off, &before, sizeof(before))) return 1;
    printf("amfid pid %d: _restrictedRequirement was %#lx\n", g_amfid, (unsigned long)before);

    ptrdiff_t off = ivar_offset("_isRunningInternalBuild");
    if (!write_amfid_byte(mgr + off, 1)) return 1;
    printf("amfid pid %d: %s+%#lx = 1\n", g_amfid, MANAGER_CLASS, (long)off);

    trigger_reload();

    for (int i = 0; i < 30; i++) {
        uintptr_t restricted = 0;
        if (read_amfid(mgr + req_off, &restricted, sizeof(restricted)) && restricted &&
            restricted != before) {
            printf(
                "amfid adopted the requirement (_restrictedRequirement %#lx -> %#lx)\n",
                (unsigned long)before,
                (unsigned long)restricted
            );
            goto live;
        }
        usleep(100 * 1000);
    }
    fprintf(stderr,
            "error: amfid did not adopt the requirement within 3s "
            "(_restrictedRequirement never moved off %#lx)\n",
            (unsigned long)before);
    return 1;

live:
    if (hold_seconds <= 0) return 0;

    // amfid has EnablePressuredExit, so it can be replaced under us; a new one
    // starts with the byte back at zero. Re-apply for as long as asked.
    printf("holding for %ds (re-applying if amfid restarts); ^C to stop\n", hold_seconds);
    for (int elapsed = 0; elapsed < hold_seconds * 5; elapsed++) {
        usleep(200 * 1000);
        if (find_amfid() == g_amfid) continue;
        printf("amfid restarted; re-applying\n");
        mach_port_deallocate(mach_task_self(), g_task);
        g_task = MACH_PORT_NULL;
        if (!attach_amfid(self_path)) return 1;
        mgr = amfid_manager(self_path);
        if (!mgr || !write_amfid_byte(mgr + off, 1)) return 1;
        trigger_reload();
    }
    return 0;
}

int cmd_off(const char *self_path) {
    bool changed = false;
    if (!remove_allow_preferences(&changed)) return 1;
    if (!changed) return 0;
    // The requirement amfid already built lives in its heap; the honest way to
    // drop it is to let launchd hand us a fresh amfid.
    pid_t pid = find_amfid();
    if (pid > 0) {
        if (kill(pid, SIGKILL) == 0)
            printf("killed amfid pid %d (launch-on-demand; it comes back clean)\n", pid);
        else
            fprintf(stderr, "error: kill %d: %s\n", pid, strerror(errno));
    }
    (void)self_path;
    return 0;
}
