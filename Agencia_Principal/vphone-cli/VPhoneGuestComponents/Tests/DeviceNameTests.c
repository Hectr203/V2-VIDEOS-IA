#include "DeviceNamePolicy.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

// MARK: - Helpers

static CFStringRef nameFromBytes(const char *bytes, CFIndex length) {
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, (const UInt8 *)bytes, length);
    CFStringRef name = VPDeviceNameCreateFromProperty(data);
    CFRelease(data);
    return name;
}

static int namesEqual(CFStringRef name, const char *expected) {
    CFStringRef want = CFStringCreateWithCString(kCFAllocatorDefault, expected, kCFStringEncodingUTF8);
    int equal = name && CFEqual(name, want);
    CFRelease(want);
    return equal;
}

static CFDictionaryRef systemValue(CFStringRef name, int encoding, int withHostName) {
    CFMutableDictionaryRef value = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks,
                                                             &kCFTypeDictionaryValueCallBacks);
    if (name)
        CFDictionarySetValue(value, VP_DEVICE_NAME_COMPUTER_NAME, name);
    CFNumberRef number = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &encoding);
    CFDictionarySetValue(value, VP_DEVICE_NAME_COMPUTER_NAME_ENCODING, number);
    CFRelease(number);
    if (withHostName)
        CFDictionarySetValue(value, CFSTR("HostName"), CFSTR("lab"));
    return value;
}

static CFStringRef computerName(CFDictionaryRef set) {
    CFDictionaryRef system = CFDictionaryGetValue(set, VP_DEVICE_NAME_SYSTEM_KEY);
    return system ? CFDictionaryGetValue(system, VP_DEVICE_NAME_COMPUTER_NAME) : NULL;
}

static int encodingIsUTF8(CFDictionaryRef set) {
    CFDictionaryRef system = CFDictionaryGetValue(set, VP_DEVICE_NAME_SYSTEM_KEY);
    CFNumberRef number = CFDictionaryGetValue(system, VP_DEVICE_NAME_COMPUTER_NAME_ENCODING);
    SInt32 encoding = 0;
    return number && CFNumberGetValue(number, kCFNumberSInt32Type, &encoding) &&
           (CFStringEncoding)encoding == kCFStringEncodingUTF8;
}

// MARK: - Name

static void decodesAName(void) {
    CFStringRef name = nameFromBytes("Lab iPhone", 10);
    assert(namesEqual(name, "Lab iPhone"));
    CFRelease(name);

    // A C-string writer's terminator is dropped.
    name = nameFromBytes("Lab iPhone\0\0", 12);
    assert(namesEqual(name, "Lab iPhone"));
    CFRelease(name);

    // UTF-8 beyond ASCII.
    name = nameFromBytes("\xe6\xb5\x8b\xe8\xaf\x95 iPhone \xe2\x80\x99", 17);
    assert(namesEqual(name, "\xe6\xb5\x8b\xe8\xaf\x95 iPhone \xe2\x80\x99"));
    CFRelease(name);

    // A CFString property is taken too.
    name = VPDeviceNameCreateFromProperty(CFSTR("Lab iPhone"));
    assert(namesEqual(name, "Lab iPhone"));
    CFRelease(name);
}

static void refusesWhatIsNotAName(void) {
    assert(!VPDeviceNameCreateFromProperty(NULL));
    assert(!nameFromBytes("", 0));
    assert(!nameFromBytes("\0\0", 2));
    assert(!VPDeviceNameCreateFromBytes(NULL, 4));
    assert(!VPDeviceNameCreateFromProperty(CFSTR("")));
    // Malformed UTF-8: a lone continuation byte, a truncated sequence, an
    // overlong encoding.
    assert(!nameFromBytes("Lab \x80", 5));
    assert(!nameFromBytes("Lab \xe6\xb5", 6));
    assert(!nameFromBytes("Lab \xc0\xaf", 6));
    // Control characters, an embedded NUL among them.
    assert(!nameFromBytes("Lab\niPhone", 10));
    assert(!nameFromBytes("Lab\0iPhone", 10));
    assert(!nameFromBytes("Lab\x7fiPhone", 10));
    assert(!VPDeviceNameCreateFromProperty(CFSTR("Lab\tiPhone")));
    // Neither data nor a string.
    int number = 1;
    CFNumberRef value = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &number);
    assert(!VPDeviceNameCreateFromProperty(value));
    CFRelease(value);

    // VP_DEVICE_NAME_MAX_BYTES bytes are taken, one more is not.
    char longest[VP_DEVICE_NAME_MAX_BYTES + 1];
    memset(longest, 'a', sizeof(longest));
    CFStringRef name = nameFromBytes(longest, VP_DEVICE_NAME_MAX_BYTES);
    assert(name && CFStringGetLength(name) == VP_DEVICE_NAME_MAX_BYTES);
    CFRelease(name);
    assert(!nameFromBytes(longest, VP_DEVICE_NAME_MAX_BYTES + 1));
    CFStringRef tooLong = CFStringCreateWithBytes(kCFAllocatorDefault, (const UInt8 *)longest, sizeof(longest),
                                                  kCFStringEncodingUTF8, false);
    assert(!VPDeviceNameCreateFromProperty(tooLong));
    CFRelease(tooLong);
}

static CFDataRef configuration(CFTypeRef name, CFPropertyListFormat format) {
    CFMutableDictionaryRef plist = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks,
                                                             &kCFTypeDictionaryValueCallBacks);
    if (name)
        CFDictionarySetValue(plist, VP_DEVICE_NAME_CONFIG_KEY, name);
    CFDictionarySetValue(plist, CFSTR("Other"), CFSTR("kept"));
    CFDataRef data = CFPropertyListCreateData(kCFAllocatorDefault, plist, format, 0, NULL);
    CFRelease(plist);
    return data;
}

static void readsTheConfiguration(void) {
    // What vphoned writes: a binary property list. XML reads the same.
    CFStringRef wanted = CFStringCreateWithCString(kCFAllocatorDefault, "dhtest 27 \xe6\xb5\x8b\xe8\xaf\x95",
                                                   kCFStringEncodingUTF8);
    CFPropertyListFormat formats[] = {kCFPropertyListBinaryFormat_v1_0, kCFPropertyListXMLFormat_v1_0};
    for (size_t index = 0; index < sizeof(formats) / sizeof(formats[0]); index++) {
        CFDataRef data = configuration(wanted, formats[index]);
        CFStringRef name = VPDeviceNameCreateFromConfiguration(data);
        assert(name && CFEqual(name, wanted));
        CFRelease(name);
        CFRelease(data);
    }
    CFRelease(wanted);

    // No key, an invalid name, a value of another type: nothing pinned.
    CFDataRef data = configuration(NULL, kCFPropertyListBinaryFormat_v1_0);
    assert(!VPDeviceNameCreateFromConfiguration(data));
    CFRelease(data);
    data = configuration(CFSTR("Lab\niPhone"), kCFPropertyListBinaryFormat_v1_0);
    assert(!VPDeviceNameCreateFromConfiguration(data));
    CFRelease(data);
    data = configuration(CFSTR(""), kCFPropertyListBinaryFormat_v1_0);
    assert(!VPDeviceNameCreateFromConfiguration(data));
    CFRelease(data);
    int number = 1;
    CFNumberRef value = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &number);
    data = configuration(value, kCFPropertyListBinaryFormat_v1_0);
    assert(!VPDeviceNameCreateFromConfiguration(data));
    CFRelease(data);
    CFRelease(value);

    // Not a property list, or not a dictionary.
    assert(!VPDeviceNameCreateFromConfiguration(NULL));
    data = CFDataCreate(kCFAllocatorDefault, (const UInt8 *)"Lab iPhone", 10);
    assert(!VPDeviceNameCreateFromConfiguration(data));
    CFRelease(data);
    data = CFPropertyListCreateData(kCFAllocatorDefault, CFSTR("Lab iPhone"), kCFPropertyListBinaryFormat_v1_0, 0,
                                    NULL);
    assert(!VPDeviceNameCreateFromConfiguration(data));
    CFRelease(data);
}

// MARK: - configd

static void pinsTheSystemValue(void) {
    // Other entries are kept; the name and its encoding are replaced.
    CFDictionaryRef original = systemValue(CFSTR("iPhone"), 0, 1);
    CFDictionaryRef pinned = VPDeviceNameCreatePinnedSystem(original, CFSTR("Lab"));
    assert(pinned);
    assert(CFEqual(CFDictionaryGetValue(pinned, VP_DEVICE_NAME_COMPUTER_NAME), CFSTR("Lab")));
    assert(CFEqual(CFDictionaryGetValue(pinned, CFSTR("HostName")), CFSTR("lab")));
    assert(CFEqual(CFDictionaryGetValue(original, VP_DEVICE_NAME_COMPUTER_NAME), CFSTR("iPhone")));
    CFRelease(pinned);
    CFRelease(original);

    // Already pinned: nothing to do.
    original = systemValue(CFSTR("Lab"), 0, 0);
    assert(!VPDeviceNameCreatePinnedSystem(original, CFSTR("Lab")));
    CFRelease(original);

    // No value, or one that is not a dictionary, gets one holding the name.
    pinned = VPDeviceNameCreatePinnedSystem(NULL, CFSTR("Lab"));
    assert(pinned && CFDictionaryGetCount(pinned) == 2);
    CFRelease(pinned);
    pinned = VPDeviceNameCreatePinnedSystem(CFSTR("junk"), CFSTR("Lab"));
    assert(pinned && CFEqual(CFDictionaryGetValue(pinned, VP_DEVICE_NAME_COMPUTER_NAME), CFSTR("Lab")));
    CFRelease(pinned);

    assert(!VPDeviceNameCreatePinnedSystem(original, NULL));
}

static CFMutableDictionaryRef publication(void) {
    return CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks,
                                     &kCFTypeDictionaryValueCallBacks);
}

static void recognisesThePreferencesMonitor(void) {
    CFMutableDictionaryRef set = publication();
    assert(!VPDeviceNameIsSetupPublication(NULL, NULL));
    assert(!VPDeviceNameIsSetupPublication(set, NULL));
    CFDictionarySetValue(set, CFSTR("State:/Network/Global/IPv4"), CFSTR("x"));
    assert(!VPDeviceNameIsSetupPublication(set, NULL));
    CFDictionarySetValue(set, CFSTR("Setup:/Network/Global/IPv4"), CFSTR("x"));
    assert(VPDeviceNameIsSetupPublication(set, NULL));
    CFRelease(set);

    const void *keys[] = {CFSTR("Setup:/Network/HostNames")};
    CFArrayRef remove = CFArrayCreate(kCFAllocatorDefault, keys, 1, &kCFTypeArrayCallBacks);
    assert(VPDeviceNameIsSetupPublication(NULL, remove));
    assert(VPDeviceNameNeedsStoredSystem(NULL, remove));
    CFRelease(remove);
}

// The monitor sets Setup:/System with the preferences' own name.
static void pinsAPublishedName(void) {
    CFMutableDictionaryRef set = publication();
    CFDictionaryRef system = systemValue(CFSTR("iPhone"), 0, 1);
    CFDictionarySetValue(set, VP_DEVICE_NAME_SYSTEM_KEY, system);
    CFDictionarySetValue(set, CFSTR("Setup:/"), CFSTR("x"));
    CFRelease(system);
    assert(!VPDeviceNameNeedsStoredSystem(set, NULL));

    CFDictionaryRef outSet = NULL;
    CFArrayRef outRemove = NULL;
    assert(VPDeviceNameCreatePinnedPublication(set, NULL, NULL, CFSTR("Lab"), &outSet, &outRemove));
    assert(outSet && !outRemove);
    assert(CFEqual(computerName(outSet), CFSTR("Lab")));
    assert(encodingIsUTF8(outSet));
    assert(CFDictionaryGetCount(outSet) == 2);
    // The caller's dictionary is untouched.
    assert(CFEqual(computerName(set), CFSTR("iPhone")));
    CFRelease(outSet);

    // A stored value is not consulted when the call sets the key itself.
    CFDictionaryRef stored = systemValue(CFSTR("Lab"), 0, 0);
    assert(VPDeviceNameCreatePinnedPublication(set, NULL, stored, CFSTR("Lab"), &outSet, &outRemove));
    CFRelease(outSet);
    CFRelease(stored);
    CFRelease(set);
}

// The monitor left Setup:/System out because it did not change.
static void pinsAnUnchangedName(void) {
    CFMutableDictionaryRef set = publication();
    CFDictionarySetValue(set, CFSTR("Setup:/"), CFSTR("x"));
    assert(VPDeviceNameNeedsStoredSystem(set, NULL));

    // The store already has the pinned name: pass the call through.
    CFDictionaryRef stored = systemValue(CFSTR("Lab"), 0, 1);
    CFDictionaryRef outSet = NULL;
    CFArrayRef outRemove = NULL;
    assert(!VPDeviceNameCreatePinnedPublication(set, NULL, stored, CFSTR("Lab"), &outSet, &outRemove));
    assert(!outSet && !outRemove);
    CFRelease(stored);

    // It has another name: the store's value, pinned, is added.
    stored = systemValue(CFSTR("iPhone"), 0, 1);
    assert(VPDeviceNameCreatePinnedPublication(set, NULL, stored, CFSTR("Lab"), &outSet, &outRemove));
    assert(CFEqual(computerName(outSet), CFSTR("Lab")));
    CFDictionaryRef system = CFDictionaryGetValue(outSet, VP_DEVICE_NAME_SYSTEM_KEY);
    assert(CFEqual(CFDictionaryGetValue(system, CFSTR("HostName")), CFSTR("lab")));
    CFRelease(outSet);
    CFRelease(stored);

    // It has none — a guest whose preferences never had a name.
    assert(VPDeviceNameCreatePinnedPublication(set, NULL, NULL, CFSTR("Lab"), &outSet, &outRemove));
    assert(CFEqual(computerName(outSet), CFSTR("Lab")));
    assert(CFDictionaryGetCount(outSet) == 2);
    CFRelease(outSet);

    // A first publication with nothing to set at all.
    assert(VPDeviceNameCreatePinnedPublication(NULL, NULL, NULL, CFSTR("Lab"), &outSet, &outRemove));
    assert(CFDictionaryGetCount(outSet) == 1 && CFEqual(computerName(outSet), CFSTR("Lab")));
    CFRelease(outSet);
    CFRelease(set);
}

// The preferences lost their System entry, so the monitor removes the key.
static void keepsARemovedName(void) {
    const void *keys[] = {CFSTR("Setup:/Network/HostNames"), VP_DEVICE_NAME_SYSTEM_KEY};
    CFArrayRef remove = CFArrayCreate(kCFAllocatorDefault, keys, 2, &kCFTypeArrayCallBacks);
    assert(!VPDeviceNameNeedsStoredSystem(NULL, remove));
    CFDictionaryRef stored = systemValue(CFSTR("Lab"), 0, 0);
    CFDictionaryRef outSet = NULL;
    CFArrayRef outRemove = NULL;
    // The stored value is not what decides: the removal must not go through.
    assert(VPDeviceNameCreatePinnedPublication(NULL, remove, stored, CFSTR("Lab"), &outSet, &outRemove));
    assert(CFEqual(computerName(outSet), CFSTR("Lab")));
    assert(outRemove && CFArrayGetCount(outRemove) == 1);
    assert(CFEqual(CFArrayGetValueAtIndex(outRemove, 0), CFSTR("Setup:/Network/HostNames")));
    assert(CFArrayGetCount(remove) == 2);
    CFRelease(outSet);
    CFRelease(outRemove);
    CFRelease(stored);
    CFRelease(remove);

    // Other removals are passed on as they are.
    const void *other[] = {CFSTR("Setup:/Network/HostNames")};
    remove = CFArrayCreate(kCFAllocatorDefault, other, 1, &kCFTypeArrayCallBacks);
    assert(VPDeviceNameCreatePinnedPublication(NULL, remove, NULL, CFSTR("Lab"), &outSet, &outRemove));
    assert(outRemove && CFEqual(outRemove, remove));
    CFRelease(outSet);
    CFRelease(outRemove);
    CFRelease(remove);
}

static void passesThroughWithoutAName(void) {
    CFMutableDictionaryRef set = publication();
    CFDictionaryRef system = systemValue(CFSTR("iPhone"), 0, 0);
    CFDictionarySetValue(set, VP_DEVICE_NAME_SYSTEM_KEY, system);
    CFRelease(system);
    CFDictionaryRef outSet = NULL;
    CFArrayRef outRemove = NULL;
    assert(!VPDeviceNameCreatePinnedPublication(set, NULL, NULL, NULL, &outSet, &outRemove));
    assert(!outSet && !outRemove);
    CFRelease(set);
}

// MARK: - lockdownd

static void refusesEveryRenameWhilePinned(void) {
    assert(VPDeviceNameAllowsRename(NULL));
    // The pinned name itself too: lockdownd would store it in the preferences.
    assert(!VPDeviceNameAllowsRename(CFSTR("Lab")));
}

int main(void) {
    decodesAName();
    refusesWhatIsNotAName();
    readsTheConfiguration();
    pinsTheSystemValue();
    recognisesThePreferencesMonitor();
    pinsAPublishedName();
    pinsAnUnchangedName();
    keepsARemovedName();
    passesThroughWithoutAName();
    refusesEveryRenameWhilePinned();
    puts("DeviceNameTests: ok");
    return 0;
}
