// This process's view of AMFIRequirementsManager, and amfid's: attaching to
// amfid, reading and writing its memory, and locating its singleton.
#include "Escalator.h"

#include <dlfcn.h>
#include <libproc.h>
#include <objc/message.h>
#include <ptrauth.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sysctl.h>
#include <sys/wait.h>
#include <unistd.h>

#define SCAN_INSNS 64 // +sharedManager is short; this is generous

mach_port_t g_task = MACH_PORT_NULL;
pid_t g_amfid = -1;

void *strip_pac(void *addr) {
#if defined(__arm64__)
    static uint32_t bits = 0;
    static int have_bits = 0;
    if (!have_bits) {
        size_t len = sizeof(bits);
        if (sysctlbyname("machdep.virtual_address_size", &bits, &len, NULL, 0) != 0) bits = -1;
        have_bits = 1;
    }
    return (void *)((uintptr_t)addr & ((1UL << bits) - 1));
#else
    return addr;
#endif
}

// --------------------------------------------------------------------------
// this process
// --------------------------------------------------------------------------

Class manager_class(void) {
    static Class cls = Nil;
    if (cls) return cls;
    if (!dlopen(AMFI_FRAMEWORK, RTLD_NOW)) {
        fprintf(stderr, "error: dlopen AppleMobileFileIntegrity: %s\n", dlerror());
        exit(1);
    }
    cls = objc_getClass(MANAGER_CLASS);
    if (!cls) {
        fprintf(
            stderr,
            "error: class %s not found — this macOS build is not supported\n",
            MANAGER_CLASS
        );
        exit(1);
    }
    return cls;
}

ptrdiff_t ivar_offset(const char *name) {
    Ivar iv = class_getInstanceVariable(manager_class(), name);
    if (!iv) {
        fprintf(
            stderr,
            "error: ivar %s not found on %s — this macOS build is not supported\n",
            name,
            MANAGER_CLASS
        );
        exit(1);
    }
    return ivar_getOffset(iv);
}

// Read from this process without faulting on an unmapped address.
static int peek_self(uintptr_t addr, void *buf, size_t len) {
    mach_vm_size_t got = 0;
    return mach_vm_read_overwrite(mach_task_self(), addr, len, (mach_vm_address_t)buf, &got) ==
               KERN_SUCCESS &&
           got == len;
}

// Decode +[AMFIRequirementsManager sharedManager] and return the static slot it
// loads the singleton out of. The slot is identified by its contents — the
// singleton this process just built — so a recompiled method that keeps the
// same shape still resolves, and one that does not is reported instead of
// guessed at.
mach_vm_address_t singleton_slot(void) {
    Class cls = manager_class();
    id local = ((id(*)(id, SEL))objc_msgSend)((id)cls, sel_registerName("sharedManager"));
    if (!local) {
        fprintf(stderr, "error: +[%s sharedManager] returned nil\n", MANAGER_CLASS);
        exit(1);
    }

    Method m = class_getClassMethod(cls, sel_registerName("sharedManager"));
    const uint32_t *code =
        ptrauth_strip((void *)method_getImplementation(m), ptrauth_key_function_pointer);

    uint64_t page[32];
    int have[32];
    memset(have, 0, sizeof(have));
    mach_vm_address_t found = 0;
    int matches = 0;

    for (int i = 0; i < SCAN_INSNS; i++) {
        uint32_t w = code[i];
        if ((w & 0x9F000000u) == 0x90000000u) { // ADRP Xd, #imm
            int rd = (int)(w & 0x1F);
            int64_t imm = (int64_t)((((w >> 5) & 0x7FFFF) << 2) | ((w >> 29) & 3));
            if (imm & (1 << 20)) imm -= (1 << 21); // sign extend 21 bits
            page[rd] = (((uint64_t)(uintptr_t)&code[i]) & ~0xFFFULL) + (uint64_t)(imm << 12);
            have[rd] = 1;
        } else if ((w & 0xFFC00000u) == 0xF9400000u) { // LDR Xt, [Xn, #imm12*8]
            int rn = (int)((w >> 5) & 0x1F);
            if (!have[rn]) continue;
            mach_vm_address_t slot = (mach_vm_address_t)(page[rn] + (((w >> 10) & 0xFFF) * 8));
            uintptr_t value = 0;
            if (peek_self((uintptr_t)slot, &value, sizeof(value)) && value == (uintptr_t)local) {
                if (found && found != slot) matches++;
                found = slot;
                matches++;
            }
        } else if (w == 0xD65F0FFFu || w == 0xD65F03C0u) { // retab / ret
            break;
        }
    }

    if (!found) {
        fprintf(stderr,
                "error: could not find the singleton slot in +[%s sharedManager] — "
                "this macOS build is not supported\n",
                MANAGER_CLASS);
        exit(1);
    }
    (void)matches; // several loads of the same slot are normal
    return found;
}

// --------------------------------------------------------------------------
// amfid
// --------------------------------------------------------------------------

pid_t find_amfid(void) {
    pid_t pids[8192];
    int n = proc_listpids(PROC_ALL_PIDS, 0, pids, (int)sizeof(pids)) / (int)sizeof(pid_t);
    char path[PROC_PIDPATHINFO_MAXSIZE];
    for (int i = 0; i < n; i++)
        if (pids[i] > 0 && proc_pidpath(pids[i], path, sizeof(path)) > 0 &&
            strcmp(path, AMFID_PATH) == 0)
            return pids[i];
    return -1;
}

// amfid is launch-on-demand. Validating this binary — ad-hoc signed, so the
// kernel has to ask — both starts it and makes it build the singleton.
static void poke_amfid(const char *self_path) {
    pid_t child = 0;
    char *const argv[] = {(char *)self_path, (char *)"--nop", NULL};
    if (posix_spawn(&child, self_path, NULL, NULL, argv, NULL) == 0) {
        int status = 0;
        waitpid(child, &status, 0);
    }
}

int attach_amfid(const char *self_path) {
    g_amfid = find_amfid();
    if (g_amfid < 0) {
        poke_amfid(self_path);
        g_amfid = find_amfid();
    }
    if (g_amfid < 0) {
        fprintf(stderr, "error: amfid is not running\n");
        return 0;
    }
    kern_return_t kr = task_for_pid(mach_task_self(), g_amfid, &g_task);
    if (kr != KERN_SUCCESS) {
        fprintf(
            stderr,
            "error: task_for_pid(%d): %s\n"
            "       needs root and SIP debugging restrictions off "
            "(csrutil enable --without debug)\n",
            g_amfid,
            mach_error_string(kr)
        );
        return 0;
    }
    return 1;
}

int read_amfid(mach_vm_address_t addr, void *buf, size_t len) {
    mach_vm_size_t got = 0;
    kern_return_t kr = mach_vm_read_overwrite(g_task, addr, len, (mach_vm_address_t)buf, &got);
    if (kr != KERN_SUCCESS) {
        fprintf(
            stderr,
            "error: read %#llx from amfid: %s\n",
            (unsigned long long)addr,
            mach_error_string(kr)
        );
        return 0;
    }
    return got == len;
}

// One byte, into a malloc'd object. No protection change, no COW of a
// shared-cache page, nothing executable — which is the entire point.
int write_amfid_byte(mach_vm_address_t addr, uint8_t value) {
    uint8_t current = 0;
    if (!read_amfid(addr, &current, 1)) return 0;
    if (current == value) return 1; // never write what is already there
    kern_return_t kr = mach_vm_write(g_task, addr, (vm_offset_t)&value, 1);
    if (kr != KERN_SUCCESS) {
        fprintf(
            stderr,
            "error: write %#llx in amfid: %s\n",
            (unsigned long long)addr,
            mach_error_string(kr)
        );
        return 0;
    }
    uint8_t back = 0;
    if (!read_amfid(addr, &back, 1) || back != value) {
        fprintf(stderr, "error: write did not take (read back %u, wanted %u)\n", back, value);
        return 0;
    }
    return 1;
}

// The singleton, with enough checking that a wrong answer stops the tool.
mach_vm_address_t amfid_manager(const char *self_path) {
    mach_vm_address_t slot = singleton_slot();
    uintptr_t remote = 0;
    if (!read_amfid(slot, &remote, sizeof(remote))) return 0;

    if (!remote) { // amfid is up but has not validated anything yet
        poke_amfid(self_path);
        usleep(200 * 1000);
        if (!read_amfid(slot, &remote, sizeof(remote))) return 0;
    }
    if (!remote) {
        fprintf(stderr, "error: amfid has not created its %s yet\n", MANAGER_CLASS);
        return 0;
    }

    remote = (uintptr_t)strip_pac((void *)remote);

    // An ObjC object here, not a stale word: the class bits of its isa have to
    // match the class bits of ours.
    const uintptr_t kISAClassBits = 0x0000000FFFFFFFF8ULL;
    uintptr_t remote_isa = 0, local_isa = (uintptr_t)manager_class();
    if (!read_amfid((mach_vm_address_t)remote, &remote_isa, sizeof(remote_isa))) return 0;
    if ((remote_isa & kISAClassBits) != (local_isa & kISAClassBits)) {
        fprintf(
            stderr,
            "error: %#lx in amfid is not an %s (isa %#lx)\n",
            (unsigned long)remote,
            MANAGER_CLASS,
            (unsigned long)remote_isa
        );
        return 0;
    }

    // Both BOOL ivars must actually read as booleans.
    uint8_t flags[2] = {0, 0};
    if (!read_amfid((mach_vm_address_t)remote + ivar_offset("_allowUnsafeDynamicLinking"),
                    &flags[0], 1) ||
        !read_amfid((mach_vm_address_t)remote + ivar_offset("_isRunningInternalBuild"), &flags[1],
                    1))
        return 0;
    if (flags[0] > 1 || flags[1] > 1) {
        fprintf(
            stderr,
            "error: %s ivars do not read as booleans (%u, %u)\n",
            MANAGER_CLASS,
            flags[0],
            flags[1]
        );
        return 0;
    }
    return (mach_vm_address_t)remote;
}
