#include "DeviceNamePolicy.h"

#include <stdlib.h>

// MARK: - Name

CFStringRef VPDeviceNameCreateFromBytes(const UInt8 *bytes, CFIndex length) {
    if (!bytes || length <= 0)
        return NULL;
    // A C-string writer leaves a terminator; drop it.
    while (length > 0 && bytes[length - 1] == 0)
        length--;
    if (length == 0 || length > VP_DEVICE_NAME_MAX_BYTES)
        return NULL;
    // No control characters, and so no embedded NUL either. Bytes of a
    // multibyte UTF-8 sequence are all 0x80 or above.
    for (CFIndex index = 0; index < length; index++) {
        if (bytes[index] < 0x20 || bytes[index] == 0x7f)
            return NULL;
    }
    // NULL for a malformed sequence.
    return CFStringCreateWithBytes(kCFAllocatorDefault, bytes, length, kCFStringEncodingUTF8, false);
}

CFStringRef VPDeviceNameCreateFromProperty(CFTypeRef property) {
    if (!property)
        return NULL;
    if (CFGetTypeID(property) == CFDataGetTypeID())
        return VPDeviceNameCreateFromBytes(CFDataGetBytePtr((CFDataRef)property),
                                           CFDataGetLength((CFDataRef)property));
    if (CFGetTypeID(property) == CFStringGetTypeID()) {
        // Checked as the bytes would be, so both forms take the same names.
        UInt8 bytes[VP_DEVICE_NAME_MAX_BYTES + 1];
        CFIndex used = 0;
        CFStringRef string = (CFStringRef)property;
        CFIndex converted = CFStringGetBytes(string, CFRangeMake(0, CFStringGetLength(string)),
                                             kCFStringEncodingUTF8, 0, false, bytes, sizeof(bytes), &used);
        if (converted != CFStringGetLength(string))
            return NULL;
        return VPDeviceNameCreateFromBytes(bytes, used);
    }
    return NULL;
}

CFStringRef VPDeviceNameCreateFromConfiguration(CFDataRef contents) {
    if (!contents)
        return NULL;
    CFPropertyListRef plist =
        CFPropertyListCreateWithData(kCFAllocatorDefault, contents, kCFPropertyListImmutable, NULL, NULL);
    if (!plist)
        return NULL;
    CFStringRef name = NULL;
    if (CFGetTypeID(plist) == CFDictionaryGetTypeID())
        name = VPDeviceNameCreateFromProperty(CFDictionaryGetValue((CFDictionaryRef)plist, VP_DEVICE_NAME_CONFIG_KEY));
    CFRelease(plist);
    return name;
}

// MARK: - configd

CFDictionaryRef VPDeviceNameCreatePinnedSystem(CFTypeRef system, CFStringRef name) {
    if (!name)
        return NULL;
    CFDictionaryRef dictionary =
        system && CFGetTypeID(system) == CFDictionaryGetTypeID() ? (CFDictionaryRef)system : NULL;
    CFTypeRef current = dictionary ? CFDictionaryGetValue(dictionary, VP_DEVICE_NAME_COMPUTER_NAME) : NULL;
    if (current && CFEqual(current, name))
        return NULL;
    CFMutableDictionaryRef pinned =
        dictionary ? CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, dictionary)
                   : CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks,
                                               &kCFTypeDictionaryValueCallBacks);
    if (!pinned)
        return NULL;
    CFDictionarySetValue(pinned, VP_DEVICE_NAME_COMPUTER_NAME, name);
    // The name came from UTF-8. The recorded encoding is only a hint for
    // converting the name to a legacy encoding, and the one the preferences
    // carry belongs to the name being replaced.
    SInt32 encoding = (SInt32)kCFStringEncodingUTF8;
    CFNumberRef number = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &encoding);
    if (number) {
        CFDictionarySetValue(pinned, VP_DEVICE_NAME_COMPUTER_NAME_ENCODING, number);
        CFRelease(number);
    }
    return pinned;
}

static Boolean vpHasSetupPrefix(CFTypeRef key) {
    return key && CFGetTypeID(key) == CFStringGetTypeID() && CFStringHasPrefix((CFStringRef)key, CFSTR("Setup:"));
}

static Boolean vpArrayContainsSystemKey(CFArrayRef keys) {
    return keys && CFArrayContainsValue(keys, CFRangeMake(0, CFArrayGetCount(keys)), VP_DEVICE_NAME_SYSTEM_KEY);
}

Boolean VPDeviceNameIsSetupPublication(CFDictionaryRef keysToSet, CFArrayRef keysToRemove) {
    if (keysToSet) {
        CFIndex count = CFDictionaryGetCount(keysToSet);
        if (count > 0) {
            const void **keys = malloc((size_t)count * sizeof(*keys));
            if (!keys)
                return false;
            CFDictionaryGetKeysAndValues(keysToSet, keys, NULL);
            Boolean found = false;
            for (CFIndex index = 0; index < count && !found; index++)
                found = vpHasSetupPrefix(keys[index]);
            free(keys);
            if (found)
                return true;
        }
    }
    if (keysToRemove) {
        for (CFIndex index = 0; index < CFArrayGetCount(keysToRemove); index++) {
            if (vpHasSetupPrefix(CFArrayGetValueAtIndex(keysToRemove, index)))
                return true;
        }
    }
    return false;
}

Boolean VPDeviceNameNeedsStoredSystem(CFDictionaryRef keysToSet, CFArrayRef keysToRemove) {
    return !(keysToSet && CFDictionaryContainsKey(keysToSet, VP_DEVICE_NAME_SYSTEM_KEY)) &&
           !vpArrayContainsSystemKey(keysToRemove);
}

Boolean VPDeviceNameCreatePinnedPublication(CFDictionaryRef keysToSet, CFArrayRef keysToRemove, CFTypeRef stored,
                                            CFStringRef name, CFDictionaryRef *outSet, CFArrayRef *outRemove) {
    *outSet = NULL;
    *outRemove = NULL;
    if (!name)
        return false;
    CFTypeRef published = keysToSet ? CFDictionaryGetValue(keysToSet, VP_DEVICE_NAME_SYSTEM_KEY) : NULL;
    const Boolean removed = vpArrayContainsSystemKey(keysToRemove);
    CFTypeRef base = published ? published : removed ? NULL : stored;
    CFDictionaryRef pinned = VPDeviceNameCreatePinnedSystem(base, name);
    // NULL: the value already names `name`. A removal always gets a value,
    // since an empty one names nothing.
    if (!pinned)
        return false;

    CFMutableDictionaryRef set =
        keysToSet ? CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, keysToSet)
                  : CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks,
                                              &kCFTypeDictionaryValueCallBacks);
    if (!set) {
        CFRelease(pinned);
        return false;
    }
    CFDictionarySetValue(set, VP_DEVICE_NAME_SYSTEM_KEY, pinned);
    CFRelease(pinned);

    CFArrayRef remove = NULL;
    if (removed) {
        CFMutableArrayRef kept = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
        if (!kept) {
            CFRelease(set);
            return false;
        }
        for (CFIndex index = 0; index < CFArrayGetCount(keysToRemove); index++) {
            CFTypeRef key = CFArrayGetValueAtIndex(keysToRemove, index);
            if (!CFEqual(key, VP_DEVICE_NAME_SYSTEM_KEY))
                CFArrayAppendValue(kept, key);
        }
        remove = kept;
    } else if (keysToRemove) {
        remove = CFRetain(keysToRemove);
    }
    *outSet = set;
    *outRemove = remove;
    return true;
}

// MARK: - lockdownd

Boolean VPDeviceNameAllowsRename(CFStringRef pinned) {
    return !pinned;
}
