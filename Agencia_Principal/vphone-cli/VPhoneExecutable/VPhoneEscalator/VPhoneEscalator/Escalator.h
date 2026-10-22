// Shared declarations for vphone-escalator. See VPhoneEscalator.c for what
// the tool does and why.
#ifndef VPHONE_ESCALATOR_H
#define VPHONE_ESCALATOR_H

#include <CoreFoundation/CoreFoundation.h>
#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <objc/runtime.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

#define AMFID_PATH "/usr/libexec/amfid"
#define AMFI_FRAMEWORK                                                         \
    "/System/Library/PrivateFrameworks/AppleMobileFileIntegrity.framework/"    \
    "AppleMobileFileIntegrity"
#define MANAGER_CLASS "AMFIRequirementsManager"
#ifndef PREFS_PATH
#define PREFS_PATH "/Library/Preferences/com.apple.security.coderequirements.plist"
#endif
// Persistent preference key; changing the executable name must not orphan
// hashes already written under this key.
#define MANAGED_KEY CFSTR("VPhoneEscalator")

extern mach_port_t g_task;
extern pid_t g_amfid;

// MARK: - AMFIDTask.c

void *strip_pac(void *addr);
Class manager_class(void);
ptrdiff_t ivar_offset(const char *name);
mach_vm_address_t singleton_slot(void);
pid_t find_amfid(void);
int attach_amfid(const char *self_path);
int read_amfid(mach_vm_address_t addr, void *buf, size_t len);
int write_amfid_byte(mach_vm_address_t addr, uint8_t value);
mach_vm_address_t amfid_manager(const char *self_path);

// MARK: - Requirements.c

CFStringRef stock_requirement(void);
CFMutableArrayRef cdhashes_for(int count, char **paths);
CFStringRef requirement_with_hashes(CFStringRef base, CFArrayRef hashes);
bool valid_hashes(CFArrayRef hashes);

// MARK: - Preferences.c

void trigger_reload(void);
int update_allow_preferences(int count, char **paths);
int remove_allow_preferences(bool *changed);

// MARK: - Commands.c

void report(const char *self_path);
int cmd_allow(const char *self_path, int count, char **paths, int hold_seconds);
int cmd_off(const char *self_path);

#endif
