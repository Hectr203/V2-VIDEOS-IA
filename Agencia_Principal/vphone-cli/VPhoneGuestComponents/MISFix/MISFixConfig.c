#include "MISFixConfig.h"

#include <dlfcn.h>
#include <fcntl.h>
#include <mach-o/dyld.h>
#include <os/log.h>
#include <ptrauth.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

// Two locations, first match wins.
//
// The override is a per-machine setting someone changes while the VM runs, so
// the preferred home is on the data volume, where vphoned's ordinary
// `files.plist_set` can write it with no remount and no new daemon code. The
// copy in /usr/lib is the one `cfw install` ships: it is the documented
// default, and it is the fallback if a daemon's sandbox turns out not to reach
// /var/db — /usr/lib is a directory installd and misagent certainly reach,
// since that is where they load this dylib from.
static const char *const kConfigPaths[] = {
    "/var/db/vphone/misfix.plist",
    "/usr/lib/libmisfix.plist",
};
static const size_t kConfigPathCount = sizeof(kConfigPaths) / sizeof(kConfigPaths[0]);

// Cached across calls. misagent is asked for the UDID once per profile, and
// installd validates every bundle in an install, so re-reading and re-parsing
// the file each time would be wasteful — but the file has to be allowed to
// change under a running daemon, or "apply the setting" would mean "reboot".
// Modification time plus size is enough to notice an edit: the plist is
// written by replacing it, never by editing bytes in place.
// The whole dictionary is kept, not just the UDID, so a second setting costs
// no second read and every value stays consistent with the file it came from.
static CFDictionaryRef gConfiguration;
static const char *gPath;
static struct timespec gStamp;
static off_t gSize;
static int gLoaded;

static CFPropertyListRef vpCopyConfigurationPlist(const char *path) {
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(
        kCFAllocatorDefault,
        (const UInt8 *)path,
        (CFIndex)strlen(path),
        false
    );
    if (url == NULL)
        return NULL;

    CFReadStreamRef stream = CFReadStreamCreateWithFile(kCFAllocatorDefault, url);
    CFRelease(url);
    if (stream == NULL)
        return NULL;

    CFPropertyListRef plist = NULL;
    if (CFReadStreamOpen(stream)) {
        plist = CFPropertyListCreateWithStream(
            kCFAllocatorDefault,
            stream,
            0,
            kCFPropertyListImmutable,
            NULL,
            NULL
        );
        CFReadStreamClose(stream);
    }
    CFRelease(stream);

    if (plist != NULL && CFGetTypeID(plist) != CFDictionaryGetTypeID()) {
        CFRelease(plist);
        return NULL;
    }
    return plist;
}

static void vpForget(void) {
    if (gConfiguration != NULL) {
        CFRelease(gConfiguration);
        gConfiguration = NULL;
    }
    gPath = NULL;
    gStamp.tv_sec = 0;
    gStamp.tv_nsec = 0;
    gSize = 0;
    gLoaded = 1;
}

/// Read `path` and adopt it as the live configuration. Returns 0 when the file
/// could not be read or parsed, in which case nothing was adopted and the
/// caller should try the next candidate.
///
/// A file that parses but sets no `UniqueDeviceID` still counts as adopted: an
/// explicitly present, valid, empty configuration means "no override", not
/// "keep looking".
static int vpAdopt(const char *path, const struct stat *info) {
    CFPropertyListRef plist = vpCopyConfigurationPlist(path);
    if (plist == NULL)
        return 0;

    if (gConfiguration != NULL)
        CFRelease(gConfiguration);
    gConfiguration = (CFDictionaryRef)plist;

    gPath = path;
    gStamp = info->st_mtimespec;
    gSize = info->st_size;
    gLoaded = 1;
    return 1;
}

/// Make `gConfiguration` current, reading again only when the file changed.
static void vpEnsureLoaded(void) {
    // Fast path: the file chosen last time, still there and unchanged. This is
    // the common case — misagent asks once per profile, installd once per
    // bundle — and it costs one `stat`.
    struct stat info;
    if (gLoaded && gPath != NULL && stat(gPath, &info) == 0
        && info.st_mtimespec.tv_sec == gStamp.tv_sec
        && info.st_mtimespec.tv_nsec == gStamp.tv_nsec
        && info.st_size == gSize)
    {
        return;
    }

    // Otherwise pick again: the first candidate that is there *and* reads.
    //
    // Selecting on `stat` alone was wrong, and quietly so. The /usr/lib copy is
    // documented as the fallback "if a daemon's sandbox turns out not to reach
    // /var/db", but a sandbox that allows metadata and denies read leaves
    // `stat` succeeding and the open failing. That picked /var/db, read
    // nothing, and reported no override — the one result indistinguishable from
    // the hook working and finding nothing configured. A file that is there but
    // unreadable now falls through to the next candidate instead.
    for (size_t index = 0; index < kConfigPathCount; index += 1) {
        struct stat candidate;
        if (stat(kConfigPaths[index], &candidate) != 0)
            continue;
        if (vpAdopt(kConfigPaths[index], &candidate))
            return;
    }

    // Nothing readable anywhere. Forget whatever was cached, so removing the
    // plist turns the override off.
    vpForget();
}

/// The value for `key` in the live configuration, or NULL.
static CFTypeRef vpConfiguredValue(CFStringRef key) {
    vpEnsureLoaded();
    if (gConfiguration == NULL)
        return NULL;
    return CFDictionaryGetValue(gConfiguration, key);
}

CFStringRef MISFixCopyConfiguredDeviceIdentifier(void) {
    CFTypeRef value = vpConfiguredValue(CFSTR("UniqueDeviceID"));
    if (value == NULL || CFGetTypeID(value) != CFStringGetTypeID()
        || CFStringGetLength((CFStringRef)value) == 0)
    {
        return NULL;
    }
    // Borrowed from the cached dictionary, which outlives the call and is only
    // replaced when the file changes.
    return (CFStringRef)value;
}

int MISFixConfiguredFlag(CFStringRef key) {
    CFTypeRef value = vpConfiguredValue(key);
    if (value == NULL || CFGetTypeID(value) != CFBooleanGetTypeID())
        return 0;
    return CFBooleanGetValue((CFBooleanRef)value) ? 1 : 0;
}

int MISFixProcessIs(const char *name) {
    char path[4096];
    uint32_t size = sizeof(path);
    if (name == NULL || _NSGetExecutablePath(path, &size) != 0)
        return 0;
    const char *slash = strrchr(path, '/');
    return strcmp(slash != NULL ? slash + 1 : path, name) == 0;
}

const char *MISFixCallerImage(const void *address) {
    if (address == NULL)
        return "?";
    // A return address on arm64e carries a pointer-authentication code; dladdr
    // compares it against image ranges as a plain address and would find
    // nothing.
    Dl_info info;
    if (dladdr(ptrauth_strip((void *)address, ptrauth_key_return_address), &info) == 0
        || info.dli_fname == NULL)
    {
        return "?";
    }
    const char *slash = strrchr(info.dli_fname, '/');
    return slash != NULL && slash[1] != '\0' ? slash + 1 : info.dli_fname;
}

// Somewhere each hooked daemon can append to, first one that opens.
//
// The unified log alone is not enough, and that cost a whole diagnosis cycle.
// vphoned's `logs.syslog` is a live tail with no lookback, so a line written
// from a constructor — which is where every hook here reports whether it
// installed — lands before any tail can be attached and is simply not there
// afterwards. A file is readable at leisure with `files.read`.
//
// installd's own cache directory is first because installd is the daemon this
// dylib is mostly about and its sandbox certainly reaches it. /var/mobile is
// for misagent and SpringBoard. /var/tmp is the last resort.
static const char *const kNotePaths[] = {
    "/var/installd/Library/Caches/libmisfix.log",
    "/var/mobile/Library/Caches/libmisfix.log",
    "/var/tmp/libmisfix.log",
};
static const size_t kNotePathCount = sizeof(kNotePaths) / sizeof(kNotePaths[0]);

static void vpAppendNote(const char *message) {
    for (size_t index = 0; index < kNotePathCount; index += 1) {
        int fd = open(kNotePaths[index], O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC, 0644);
        if (fd < 0)
            continue;
        dprintf(fd, "libmisfix[%d]: %s\n", getpid(), message);
        close(fd);
        return;
    }
}

void MISFixNote(const char *format, ...) {
    char message[512];
    va_list arguments;
    va_start(arguments, format);
    int written = vsnprintf(message, sizeof(message), format, arguments);
    va_end(arguments);
    if (written <= 0)
        return;
    // One prefix for every line this dylib writes, so a single predicate finds
    // them whichever process is carrying the hook.
    os_log(OS_LOG_DEFAULT, "libmisfix[%d]: %{public}s", getpid(), message);
    vpAppendNote(message);
}

void MISFixLog(const char *format, ...) {
    if (!MISFixConfiguredFlag(kMISFixLogQueriesKey))
        return;
    char message[512];
    va_list arguments;
    va_start(arguments, format);
    int written = vsnprintf(message, sizeof(message), format, arguments);
    va_end(arguments);
    if (written <= 0)
        return;
    MISFixNote("%s", message);
}

int MISFixProcessOnlyNeedsIdentity(void) {
    return MISFixProcessIs("lockdownd") || MISFixProcessIs("remoted");
}
