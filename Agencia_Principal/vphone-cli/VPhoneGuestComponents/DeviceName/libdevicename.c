// libdevicename.c — pin the guest's device name to the one the host chose,
// and refuse renaming it inside the guest.
//
// ## Where the name lives
//
// The device name is `System/System/ComputerName` in
// /private/var/preferences/SystemConfiguration/preferences.plist. configd
// (/usr/libexec/configd, a standalone image) publishes it into the dynamic
// store as `Setup:/System`, and every reader goes through the store:
// lockdownd's `copy_device_name` (`SCDynamicStoreCopyComputerName`, what
// lockdown `GetValue DeviceName`, Finder and Xcode see), MobileGestalt's
// UserAssignedDeviceName and UIDevice.name. Renames come in through lockdownd's
// `set_device_name`, which calls `SCPreferencesSetComputerName`,
// `SCPreferencesSetHostName` and `SCPreferencesSetLocalHostName` (its only
// callers of them) and commits.
//
// ## The channel
//
// The name is `DeviceName` in /var/db/vphone/devicename.plist. vphoned writes
// it, in one rename, when the host calls `device.name.set`, which vphone-vm
// does after every connect with the VM's name, and removes it for a null name.
// The file survives a reboot, so configd's first publication at boot already
// carries the name, before lockdownd first reads it. Both daemons check the
// file on every decision and read it again when it changed, so a new name
// applies while the guest runs: vphoned then has configd publish again.
// Absent, unreadable or not a valid name (DeviceNamePolicy.c) means nothing is
// pinned, and every interpose here passes its call through unchanged.
//
// An NVRAM variable written by the host before boot was the first channel. It
// never reaches the guest: iBoot keeps only the variables it knows
// (Research/Guest/device_name_pinning.md).
//
// ## configd: the published name is the pinned one
//
// configd's preferences monitor (`updateConfiguration` in configd's
// PreferencesMonitor, statically linked into configd; 24A435:
// 0x100062098..0x100062d00) flattens `SCPreferencesGetValue(prefs,
// kSCPrefSystem)` into `Setup:/...` keys, compares them with what the store
// already has (`SCDynamicStoreCopyMultiple("^Setup:.*")`), leaves out the keys
// that did not change, and publishes the rest with one
// `SCDynamicStoreSetMultiple(store, keysToSet, keysToRemove, NULL)`. It runs on
// every apply of the preferences, also one that changed nothing in them.
//
// The pin goes in at that publication, not at the preferences read:
// `SCDynamicStoreSetMultiple` is interposed and, for a call that touches the
// `Setup:` domain, `Setup:/System`'s ComputerName becomes the pinned name
// (VPDeviceNameCreatePinnedPublication). When the call leaves the key out
// because it did not change, the store's current value is read and pinned if it
// does not already say so, and when it removes the key it is set instead. So a
// guest whose preferences never had a name gets the pinned one too.
// `SCDynamicStoreSetValue` of `Setup:/System` is pinned the same way, though no
// configd caller is known to set that key on its own.
//
// That is how a name set while the guest runs takes effect: vphoned applies
// the preferences unchanged and the monitor publishes again. With the store
// holding the guest's own name the call leaves `Setup:/System` out, and the
// store's value gets the new pin; with an older pin in the store the call
// sets the preferences' value, which is pinned. Once nothing is pinned, the
// store's pin differs from the preferences, so the call sets their value and
// the guest's own name returns (measured, 24A435).
//
// Substituting the `kSCPrefSystem` value from `SCPreferencesGetValue` would be
// read by the same flattening, but configd also reads that value to write it
// back: the monitor's model-change path (24A435 sub_10006155c) does
// `SCPreferencesGetValue(prefs, kSCPrefSystem)`,
// `__SCNetworkConfigurationSaveModel`, `SCPreferencesSetValue(prefs,
// kSCPrefSystem, same)`, which would commit the pinned name to disk. The
// publication route never changes preferences.plist.
//
// set-hostname's `__SCPreferencesCopyComputerName` reads the preferences file
// directly, to derive a DNS host name from a reverse lookup; it is not a
// display name and is left alone.
//
// ## lockdownd: renames are refused
//
// While a name is pinned, `SCPreferencesSetComputerName` returns false with
// `kSCStatusAccessError`, and the host name and local host name setters that
// follow on the same preferences object do too, so the preferences keep their
// name. `set_device_name` only logs each setter's failure and its SetValue
// handler ignores the result, so a host that renames sees success and the name
// stays.
//
// The pinned name itself is refused as well. lockdownd names the device every
// time it starts (24A435 0x100011e4c): `set_device_name(copy_device_name())`,
// or `MarketingDeviceFamilyName` when there is none. At boot it runs before
// configd has published and gets the name the preferences already hold
// (measured). A lockdownd started later (a crash, or
// vphoned's `udid.set` stopping it) reads the pinned name from the store, and
// letting that through wrote it, a host name and a local host name derived
// from it into preferences.plist (measured: `dhtest-27-ceshi`).
//
// ## Reach
//
// configd and lockdownd are standalone images, so their imports bind through
// dyld's interposing table; calls inside the shared cache do not, which is why
// the hooks sit on the daemons' own imports. Both spawn hooks insert this into
// those two processes only (`vpIsDeviceNameTarget` in
// Shared/InjectionEnvironment.h); lockdownd takes it after libmisfix. Each
// interpose checks which of the two it is in.
//
// ## Assumptions to confirm on a guest
//
//   - configd's PreferencesMonitor is the only publisher of `Setup:/System`;
//   - Settings' General > About > Name goes through lockdownd. If it writes the
//     preferences itself, configd still publishes the pinned name.

#include "DeviceNamePolicy.h"

#include <CoreFoundation/CoreFoundation.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

// MARK: - SystemConfiguration

// Exported by SystemConfiguration on iOS, but its headers mark them
// unavailable there, so they are declared here.
typedef const struct __SCDynamicStore *VPSCDynamicStoreRef;
typedef const struct __SCPreferences *VPSCPreferencesRef;

extern Boolean SCDynamicStoreSetMultiple(VPSCDynamicStoreRef store, CFDictionaryRef keysToSet,
                                         CFArrayRef keysToRemove, CFArrayRef keysToNotify);
extern Boolean SCDynamicStoreSetValue(VPSCDynamicStoreRef store, CFStringRef key, CFPropertyListRef value);
extern CFPropertyListRef SCDynamicStoreCopyValue(VPSCDynamicStoreRef store, CFStringRef key);
extern Boolean SCPreferencesSetComputerName(VPSCPreferencesRef prefs, CFStringRef name, CFStringEncoding encoding);
extern Boolean SCPreferencesSetHostName(VPSCPreferencesRef prefs, CFStringRef name);
extern Boolean SCPreferencesSetLocalHostName(VPSCPreferencesRef prefs, CFStringRef name);
// SCPrivate.h; what SCError() returns next.
extern void _SCErrorSet(int error);

// SystemConfiguration.h: "Permission denied".
#define VP_SC_STATUS_ACCESS_ERROR 1003

// MARK: - Log

// configd and lockdownd both run as root, but the mode keeps the log open to
// the other guest libraries' writers, as in SystemHook. Bounded twice: lines
// per process, and the file's size, since configd republishes on every
// preferences change for the life of the guest.
#define VP_LOG_PATH "/var/mobile/Library/Caches/vphone-devicename.log"
#define VP_LOG_MAX_LINES 64
#define VP_LOG_MAX_BYTES (256 * 1024)

static void vpLog(const char *format, ...) __attribute__((format(printf, 1, 2)));
static void vpLog(const char *format, ...) {
    static atomic_int lines;
    if (atomic_fetch_add(&lines, 1) >= VP_LOG_MAX_LINES)
        return;
    int fd = open(VP_LOG_PATH, O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC, 0666);
    if (fd < 0)
        return;
    fchmod(fd, 0666);
    struct stat info;
    if (fstat(fd, &info) == 0 && info.st_size < VP_LOG_MAX_BYTES) {
        char line[768];
        va_list arguments;
        va_start(arguments, format);
        vsnprintf(line, sizeof(line), format, arguments);
        va_end(arguments);
        dprintf(fd, "pid=%d %s %s\n", getpid(), getprogname(), line);
    }
    close(fd);
}

// A name for the log, truncated to fit.
static const char *vpDescribe(CFStringRef string, char *buffer, size_t size) {
    if (!string)
        return "<null>";
    if (!CFStringGetCString(string, buffer, (CFIndex)size, kCFStringEncodingUTF8))
        snprintf(buffer, size, "<unprintable>");
    return buffer;
}

// MARK: - Pinned Name

enum { VPRoleOther, VPRoleConfigd, VPRoleLockdownd };

static int vpRole;

// The name last read from VP_DEVICE_NAME_CONFIG_PATH and the file it came from.
// The host sets the name after every connect, and a rename changes it while the
// guest runs, so the file is checked on every decision; it is read again only
// when its identity, size or modification time changed. vphoned replaces it in
// one rename, so a new inode or time marks every write.
static pthread_mutex_t vpPinnedLock = PTHREAD_MUTEX_INITIALIZER;
static CFStringRef vpPinned;
static struct stat vpPinnedStamp;
static Boolean vpPinnedRead;

static Boolean vpSameStamp(const struct stat *a, const struct stat *b) {
    return a->st_dev == b->st_dev && a->st_ino == b->st_ino && a->st_size == b->st_size &&
           a->st_mtimespec.tv_sec == b->st_mtimespec.tv_sec && a->st_mtimespec.tv_nsec == b->st_mtimespec.tv_nsec;
}

// The name in the file `fd` reads, or NULL.
static CFStringRef vpCopyConfiguredName(int fd, off_t size) {
    if (size <= 0 || size > 64 * 1024)
        return NULL;
    UInt8 *bytes = malloc((size_t)size);
    if (!bytes)
        return NULL;
    ssize_t count = pread(fd, bytes, (size_t)size, 0);
    CFStringRef name = NULL;
    if (count == size) {
        CFDataRef contents = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, bytes, size, kCFAllocatorNull);
        if (contents) {
            name = VPDeviceNameCreateFromConfiguration(contents);
            CFRelease(contents);
        }
    }
    free(bytes);
    return name;
}

// Make vpPinned match the file. Called with vpPinnedLock held.
static void vpRefreshPinned(void) {
    struct stat info;
    const Boolean present = stat(VP_DEVICE_NAME_CONFIG_PATH, &info) == 0;
    if (vpPinnedRead && (present ? vpSameStamp(&info, &vpPinnedStamp) : vpPinnedStamp.st_ino == 0))
        return;
    CFStringRef name = NULL;
    memset(&vpPinnedStamp, 0, sizeof(vpPinnedStamp));
    if (present) {
        int fd = open(VP_DEVICE_NAME_CONFIG_PATH, O_RDONLY | O_CLOEXEC);
        if (fd >= 0) {
            // The stamp of what is read, not of what stat saw a moment ago.
            if (fstat(fd, &vpPinnedStamp) == 0)
                name = vpCopyConfiguredName(fd, vpPinnedStamp.st_size);
            close(fd);
        }
        if (!name)
            vpLog("%s holds no valid name; nothing is pinned", VP_DEVICE_NAME_CONFIG_PATH);
    }
    vpPinnedRead = true;
    char buffer[VP_DEVICE_NAME_MAX_BYTES + 1];
    if (name && !(vpPinned && CFEqual(name, vpPinned)))
        vpLog("pinned name \"%s\"", vpDescribe(name, buffer, sizeof(buffer)));
    else if (!name && vpPinned)
        vpLog("no name pinned any more");
    if (vpPinned)
        CFRelease(vpPinned);
    vpPinned = name;
}

// The pinned name for the process this hook acts in, retained, or NULL to pass
// through.
static CFStringRef vpCopyPinnedName(int role) {
    if (vpRole != role)
        return NULL;
    pthread_mutex_lock(&vpPinnedLock);
    vpRefreshPinned();
    CFStringRef name = vpPinned ? CFRetain(vpPinned) : NULL;
    pthread_mutex_unlock(&vpPinnedLock);
    return name;
}

// MARK: - configd

static Boolean vpSetMultiple(VPSCDynamicStoreRef store, CFDictionaryRef keysToSet, CFArrayRef keysToRemove,
                             CFArrayRef keysToNotify) {
    // configd's other plugins publish State: keys through here all the time;
    // they never touch the file.
    if (vpRole != VPRoleConfigd || !VPDeviceNameIsSetupPublication(keysToSet, keysToRemove))
        return SCDynamicStoreSetMultiple(store, keysToSet, keysToRemove, keysToNotify);
    CFStringRef name = vpCopyPinnedName(VPRoleConfigd);
    if (!name)
        return SCDynamicStoreSetMultiple(store, keysToSet, keysToRemove, keysToNotify);
    CFPropertyListRef stored = VPDeviceNameNeedsStoredSystem(keysToSet, keysToRemove)
                                   ? SCDynamicStoreCopyValue(store, VP_DEVICE_NAME_SYSTEM_KEY)
                                   : NULL;
    CFDictionaryRef set = NULL;
    CFArrayRef remove = NULL;
    const Boolean changed = VPDeviceNameCreatePinnedPublication(keysToSet, keysToRemove, stored, name, &set, &remove);
    if (stored)
        CFRelease(stored);
    Boolean result;
    if (changed) {
        result = SCDynamicStoreSetMultiple(store, set, remove, keysToNotify);
        char buffer[VP_DEVICE_NAME_MAX_BYTES + 1];
        vpLog("published Setup:/System ComputerName \"%s\" result=%d", vpDescribe(name, buffer, sizeof(buffer)),
              result);
        CFRelease(set);
        if (remove)
            CFRelease(remove);
    } else {
        result = SCDynamicStoreSetMultiple(store, keysToSet, keysToRemove, keysToNotify);
    }
    CFRelease(name);
    return result;
}

static Boolean vpSetValue(VPSCDynamicStoreRef store, CFStringRef key, CFPropertyListRef value) {
    if (vpRole != VPRoleConfigd || !key || !CFEqual(key, VP_DEVICE_NAME_SYSTEM_KEY))
        return SCDynamicStoreSetValue(store, key, value);
    CFStringRef name = vpCopyPinnedName(VPRoleConfigd);
    CFDictionaryRef pinned = name ? VPDeviceNameCreatePinnedSystem(value, name) : NULL;
    Boolean result;
    if (pinned) {
        result = SCDynamicStoreSetValue(store, key, pinned);
        char buffer[VP_DEVICE_NAME_MAX_BYTES + 1];
        vpLog("set Setup:/System ComputerName \"%s\" result=%d", vpDescribe(name, buffer, sizeof(buffer)), result);
        CFRelease(pinned);
    } else {
        result = SCDynamicStoreSetValue(store, key, value);
    }
    if (name)
        CFRelease(name);
    return result;
}

// MARK: - lockdownd

// The preferences object whose ComputerName was just refused on this thread.
// set_device_name makes one per rename and calls the three setters on it in
// turn, so the host name setters follow the ComputerName decision.
static __thread VPSCPreferencesRef vpRefusedPreferences;

static Boolean vpRefuse(const char *setter, CFStringRef requested, CFStringRef pinned) {
    char wanted[VP_DEVICE_NAME_MAX_BYTES + 1];
    char kept[VP_DEVICE_NAME_MAX_BYTES + 1];
    vpLog("refused %s(\"%s\"): the name is pinned to \"%s\"", setter, vpDescribe(requested, wanted, sizeof(wanted)),
          vpDescribe(pinned, kept, sizeof(kept)));
    _SCErrorSet(VP_SC_STATUS_ACCESS_ERROR);
    return false;
}

static Boolean vpSetComputerName(VPSCPreferencesRef prefs, CFStringRef name, CFStringEncoding encoding) {
    CFStringRef pinned = vpCopyPinnedName(VPRoleLockdownd);
    Boolean result;
    if (VPDeviceNameAllowsRename(pinned)) {
        vpRefusedPreferences = NULL;
        result = SCPreferencesSetComputerName(prefs, name, encoding);
    } else {
        vpRefusedPreferences = prefs;
        result = vpRefuse("SCPreferencesSetComputerName", name, pinned);
    }
    if (pinned)
        CFRelease(pinned);
    return result;
}

// The host name setters after a refused ComputerName on the same preferences.
static Boolean vpRefuseFollowing(const char *setter, VPSCPreferencesRef prefs, CFStringRef name) {
    if (vpRole != VPRoleLockdownd || !prefs || prefs != vpRefusedPreferences)
        return false;
    CFStringRef pinned = vpCopyPinnedName(VPRoleLockdownd);
    vpRefuse(setter, name, pinned);
    if (pinned)
        CFRelease(pinned);
    return true;
}

static Boolean vpSetHostName(VPSCPreferencesRef prefs, CFStringRef name) {
    if (vpRefuseFollowing("SCPreferencesSetHostName", prefs, name))
        return false;
    return SCPreferencesSetHostName(prefs, name);
}

static Boolean vpSetLocalHostName(VPSCPreferencesRef prefs, CFStringRef name) {
    if (vpRefuseFollowing("SCPreferencesSetLocalHostName", prefs, name)) {
        // The last of set_device_name's three setters.
        vpRefusedPreferences = NULL;
        return false;
    }
    return SCPreferencesSetLocalHostName(prefs, name);
}

// MARK: - Load

__attribute__((constructor)) static void vpDeviceNameInit(void) {
    const char *name = getprogname();
    vpRole = name && strcmp(name, "configd") == 0     ? VPRoleConfigd
             : name && strcmp(name, "lockdownd") == 0 ? VPRoleLockdownd
                                                      : VPRoleOther;
}

int vphone_devicename_version(void) { return 1; }

// Easy to change: each row is one import of configd or lockdownd. Which of
// the two a row acts in is decided by the role each interpose checks.
__attribute__((used, section("__DATA,__interpose"))) static const struct {
    const void *replacement;
    const void *replacee;
} vpInterpose[] = {
    {(const void *)vpSetMultiple, (const void *)SCDynamicStoreSetMultiple},
    {(const void *)vpSetValue, (const void *)SCDynamicStoreSetValue},
    {(const void *)vpSetComputerName, (const void *)SCPreferencesSetComputerName},
    {(const void *)vpSetHostName, (const void *)SCPreferencesSetHostName},
    {(const void *)vpSetLocalHostName, (const void *)SCPreferencesSetLocalHostName},
};
