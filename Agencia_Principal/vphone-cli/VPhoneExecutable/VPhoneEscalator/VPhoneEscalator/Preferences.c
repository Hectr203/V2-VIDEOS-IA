// The coderequirements preference: reading, writing, reloading, and the
// vphone-escalator entries kept in it.
#include "Escalator.h"

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <unistd.h>

static CFMutableDictionaryRef read_prefs(bool *existed) {
    int fd = open(PREFS_PATH, O_RDONLY | O_NOFOLLOW);
    if (fd < 0 && errno == ENOENT) {
        *existed = false;
        return CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks,
                                         &kCFTypeDictionaryValueCallBacks);
    }
    if (fd < 0) {
        fprintf(stderr, "error: open %s: %s\n", PREFS_PATH, strerror(errno));
        return NULL;
    }
    *existed = true;
    struct stat st;
    if (fstat(fd, &st) || !S_ISREG(st.st_mode) || st.st_size < 0 || st.st_size > 1024 * 1024) {
        fprintf(stderr, "error: %s is not a regular plist under 1 MiB\n", PREFS_PATH);
        close(fd);
        return NULL;
    }
    UInt8 *bytes = malloc(st.st_size ? (size_t)st.st_size : 1);
    if (!bytes) { close(fd); return NULL; }
    size_t done = 0;
    while (done < (size_t)st.st_size) {
        ssize_t n = read(fd, bytes + done, (size_t)st.st_size - done);
        if (n <= 0) break;
        done += (size_t)n;
    }
    close(fd);
    if (done != (size_t)st.st_size) {
        fprintf(stderr, "error: could not read %s completely\n", PREFS_PATH);
        free(bytes);
        return NULL;
    }
    CFDataRef data = CFDataCreate(NULL, bytes, (CFIndex)done);
    free(bytes);
    CFPropertyListRef plist = CFPropertyListCreateWithData(NULL, data,
        kCFPropertyListMutableContainersAndLeaves, NULL, NULL);
    CFRelease(data);
    if (!plist || CFGetTypeID(plist) != CFDictionaryGetTypeID()) {
        fprintf(stderr, "error: %s is not a valid dictionary plist\n", PREFS_PATH);
        if (plist) CFRelease(plist);
        return NULL;
    }
    return (CFMutableDictionaryRef)plist;
}

static int write_prefs(CFDictionaryRef d) {
    CFDataRef data = CFPropertyListCreateData(NULL, d, kCFPropertyListXMLFormat_v1_0, 0, NULL);
    if (!data) return 0;

    char tmp[] = PREFS_PATH ".XXXXXX";
    int fd = mkstemp(tmp);
    if (fd < 0) {
        fprintf(stderr, "error: %s: %s\n", tmp, strerror(errno));
        CFRelease(data);
        return 0;
    }
    const UInt8 *bytes = CFDataGetBytePtr(data);
    size_t length = (size_t)CFDataGetLength(data), done = 0;
    while (done < length) {
        ssize_t n = write(fd, bytes + done, length - done);
        if (n <= 0) break;
        done += (size_t)n;
    }
    CFRelease(data);
    struct stat old;
    bool had_old = stat(PREFS_PATH, &old) == 0;
    int ok = done == length && fchmod(fd, had_old ? old.st_mode & 0777 : 0644) == 0 &&
             fchown(fd, had_old ? old.st_uid : geteuid(),
                    had_old ? old.st_gid : getegid()) == 0 &&
             fsync(fd) == 0;
    if (close(fd) != 0) ok = 0;
    if (!ok) {
        fprintf(stderr, "error: could not write %s: %s\n", tmp, strerror(errno));
        unlink(tmp);
        return 0;
    }
    if (rename(tmp, PREFS_PATH) != 0) {
        fprintf(stderr, "error: rename %s: %s\n", PREFS_PATH, strerror(errno));
        unlink(tmp);
        return 0;
    }
    return 1;
}

// launchd watches this path and pokes amfid; touching it is the reload.
void trigger_reload(void) { utimes(PREFS_PATH, NULL); }

// --------------------------------------------------------------------------

int update_allow_preferences(int count, char **paths) {
    bool existed = false;
    CFMutableDictionaryRef prefs = read_prefs(&existed);
    if (!prefs) return 1;
    CFTypeRef current = CFDictionaryGetValue(prefs, CFSTR("Entitlements"));
    CFTypeRef unsafe = CFDictionaryGetValue(prefs, CFSTR("AllowUnsafeDynamicLinking"));
    CFDictionaryRef managed = CFDictionaryGetValue(prefs, MANAGED_KEY);
    if ((current && CFGetTypeID(current) != CFStringGetTypeID()) ||
        (managed && CFGetTypeID(managed) != CFDictionaryGetTypeID())) {
        fprintf(stderr, "error: %s has unexpected value types\n", PREFS_PATH);
        CFRelease(prefs);
        return 1;
    }
    CFStringRef base = NULL;
    CFMutableArrayRef hashes = NULL;
    bool had_entitlements = current != NULL;
    if (managed) {
        base = CFDictionaryGetValue(managed, CFSTR("Base"));
        CFArrayRef saved = CFDictionaryGetValue(managed, CFSTR("Hashes"));
        CFTypeRef original_entitlements = CFDictionaryGetValue(managed, CFSTR("HadEntitlements"));
        if (!base || CFGetTypeID(base) != CFStringGetTypeID() || !valid_hashes(saved) ||
            !original_entitlements ||
            CFGetTypeID(original_entitlements) != CFBooleanGetTypeID()) {
            fprintf(stderr, "error: invalid %s metadata in %s\n", "vphone-escalator", PREFS_PATH);
            CFRelease(prefs);
            return 1;
        }
        hashes = CFArrayCreateMutableCopy(NULL, 0, saved);
        CFStringRef expected = requirement_with_hashes(base, hashes);
        bool matches = current && CFEqual(current, expected);
        CFRelease(expected);
        if (!matches) {
            fprintf(stderr, "error: Entitlements changed since vphone-escalator wrote it\n");
            CFRelease(hashes);
            CFRelease(prefs);
            return 1;
        }
        had_entitlements = CFBooleanGetValue(original_entitlements);
    } else {
        base = current ? CFRetain(current) : stock_requirement();
        hashes = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
    }

    CFMutableArrayRef incoming = cdhashes_for(count, paths);
    bool added = false;
    for (CFIndex i = 0; i < CFArrayGetCount(incoming); i++) {
        CFStringRef hash = CFArrayGetValueAtIndex(incoming, i);
        CFMutableStringRef clause = CFStringCreateMutable(NULL, 0);
        CFStringAppend(clause, CFSTR("cdhash H\""));
        CFStringAppend(clause, hash);
        CFStringAppend(clause, CFSTR("\""));
        bool already_present = CFStringFind(base, clause, kCFCompareCaseInsensitive).location !=
                               kCFNotFound;
        CFRelease(clause);
        if (!already_present && !CFArrayContainsValue(hashes, CFRangeMake(0, CFArrayGetCount(hashes)), hash)) {
            CFArrayAppendValue(hashes, hash);
            added = true;
        }
    }
    CFRelease(incoming);
    CFStringRef req = requirement_with_hashes(base, hashes);
    char buf[4096];
    if (CFStringGetCString(req, buf, sizeof(buf), kCFStringEncodingUTF8))
        printf("requirement: %s\n", buf);
    else
        printf("requirement: %ld characters\n", CFStringGetLength(req));

    if (added) {
        CFMutableDictionaryRef tracking = CFDictionaryCreateMutable(NULL, 0,
            &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFDictionarySetValue(tracking, CFSTR("Base"), base);
        CFDictionarySetValue(tracking, CFSTR("Hashes"), hashes);
        CFDictionarySetValue(tracking, CFSTR("HadEntitlements"), had_entitlements ? kCFBooleanTrue : kCFBooleanFalse);
        CFDictionarySetValue(prefs, MANAGED_KEY, tracking);
        CFRelease(tracking);
        CFDictionarySetValue(prefs, CFSTR("Entitlements"), req);
    }
    // Entitlements without this key enables unsafe dynamic linking globally.
    // Leave any existing value untouched, including values set by another tool.
    if (!unsafe) CFDictionarySetValue(prefs, CFSTR("AllowUnsafeDynamicLinking"), kCFBooleanFalse);
    if (added || !unsafe) {
        if (!write_prefs(prefs)) {
            CFRelease(req);
            CFRelease(hashes);
            if (!managed) CFRelease(base);
            CFRelease(prefs);
            return 1;
        }
        printf("updated %s\n", PREFS_PATH);
    } else {
        printf("cdhash already allowed; left %s unchanged\n", PREFS_PATH);
    }
    CFRelease(req);
    CFRelease(hashes);
    if (!managed) CFRelease(base);
    CFRelease(prefs);
    return 0;
}

int remove_allow_preferences(bool *changed) {
    *changed = false;
    bool existed = false;
    CFMutableDictionaryRef prefs = read_prefs(&existed);
    if (!prefs) return 0;
    CFDictionaryRef managed = CFDictionaryGetValue(prefs, MANAGED_KEY);
    if (managed) {
        if (CFGetTypeID(managed) != CFDictionaryGetTypeID()) {
            fprintf(stderr, "error: invalid vphone-escalator metadata\n");
            CFRelease(prefs);
            return 0;
        }
        CFStringRef base = CFDictionaryGetValue(managed, CFSTR("Base"));
        CFArrayRef hashes = CFDictionaryGetValue(managed, CFSTR("Hashes"));
        CFTypeRef had_entitlements = CFDictionaryGetValue(managed, CFSTR("HadEntitlements"));
        if (!base || CFGetTypeID(base) != CFStringGetTypeID() || !valid_hashes(hashes) ||
            !had_entitlements ||
            CFGetTypeID(had_entitlements) != CFBooleanGetTypeID()) {
            fprintf(stderr, "error: invalid vphone-escalator metadata\n");
            CFRelease(prefs);
            return 0;
        }
        CFStringRef expected = requirement_with_hashes(base, hashes);
        CFTypeRef current = CFDictionaryGetValue(prefs, CFSTR("Entitlements"));
        bool matches = current && CFGetTypeID(current) == CFStringGetTypeID() &&
                       CFEqual(current, expected);
        CFRelease(expected);
        if (!matches) {
            fprintf(stderr, "error: Entitlements changed since vphone-escalator wrote it; refusing to remove other rules\n");
            CFRelease(prefs);
            return 0;
        }
        if (CFBooleanGetValue(had_entitlements))
            CFDictionarySetValue(prefs, CFSTR("Entitlements"), base);
        else
            CFDictionaryRemoveValue(prefs, CFSTR("Entitlements"));
        CFDictionaryRemoveValue(prefs, MANAGED_KEY);
        if (!write_prefs(prefs)) { CFRelease(prefs); return 0; }
        printf("removed vphone-escalator cdhashes from %s\n", PREFS_PATH);
    } else {
        printf("no vphone-escalator entries to remove\n");
        CFRelease(prefs);
        return 1;
    }
    CFRelease(prefs);
    *changed = true;
    return 1;
}
