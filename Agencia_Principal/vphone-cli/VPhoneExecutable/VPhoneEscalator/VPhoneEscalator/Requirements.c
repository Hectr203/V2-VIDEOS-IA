// cdhash collection and the code requirement strings built from them.
#include "Escalator.h"

#include <Security/Security.h>
#include <objc/message.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// --------------------------------------------------------------------------
// cdhashes and the preference
// --------------------------------------------------------------------------

// What amfid would use if this tool had never run. -init builds it through
// -resetRestrictedRequirement, so this process's own singleton is carrying it
// right now: ask that one rather than hardcoding a string that changes with
// the OS. Ours is then this, plus a cdhash — strictly more permissive, never
// less.
CFStringRef stock_requirement(void) {
    Class cls = manager_class();
    id mgr = ((id(*)(id, SEL))objc_msgSend)((id)cls, sel_registerName("sharedManager"));
    SecRequirementRef stock = ((SecRequirementRef(*)(id, SEL))objc_msgSend)(
        mgr,
        sel_registerName("restrictedRequirement")
    );
    CFStringRef text = NULL;
    if (!stock || SecRequirementCopyString(stock, kSecCSDefaultFlags, &text) != errSecSuccess ||
        !text) {
        fprintf(stderr, "error: cannot read the stock restricted requirement — "
                        "this macOS build is not supported\n");
        exit(1);
    }
    return text;
}

CFMutableArrayRef cdhashes_for(int count, char **paths) {
    CFMutableArrayRef result = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
    for (int i = 0; i < count; i++) {
        CFURLRef url = CFURLCreateFromFileSystemRepresentation(
            NULL,
            (const UInt8 *)paths[i],
            (CFIndex)strlen(paths[i]),
            false
        );
        SecStaticCodeRef code = NULL;
        OSStatus st = SecStaticCodeCreateWithPath(url, kSecCSDefaultFlags, &code);
        CFRelease(url);
        if (st != errSecSuccess) {
            fprintf(stderr, "error: %s: not signed code (%d)\n", paths[i], (int)st);
            exit(1);
        }

        // kSecCSSigningInformation is what fills in kSecCodeInfoCdHashes — every
        // code directory, so a universal binary gets each slice allowlisted
        // rather than only the one kSecCodeInfoUnique happens to name.
        CFDictionaryRef info = NULL;
        st = SecCodeCopySigningInformation(code, kSecCSSigningInformation, &info);
        CFRelease(code);
        if (st != errSecSuccess) {
            fprintf(
                stderr,
                "error: %s: cannot read signing information (%d)\n",
                paths[i],
                (int)st
            );
            exit(1);
        }

        CFArrayRef hashes = CFDictionaryGetValue(info, kSecCodeInfoCdHashes);
        CFDataRef unique = CFDictionaryGetValue(info, kSecCodeInfoUnique);
        CFIndex n = hashes ? CFArrayGetCount(hashes) : (unique ? 1 : 0);
        if (n == 0) {
            fprintf(stderr, "error: %s: no cdhash\n", paths[i]);
            exit(1);
        }
        for (CFIndex h = 0; h < n; h++) {
            CFDataRef d = hashes ? CFArrayGetValueAtIndex(hashes, h) : unique;
            CFMutableStringRef hash = CFStringCreateMutable(NULL, 0);
            const UInt8 *b = CFDataGetBytePtr(d);
            for (CFIndex k = 0; k < CFDataGetLength(d); k++)
                CFStringAppendFormat(hash, NULL, CFSTR("%02x"), b[k]);
            if (!CFArrayContainsValue(result, CFRangeMake(0, CFArrayGetCount(result)), hash))
                CFArrayAppendValue(result, hash);
            CFRelease(hash);
        }
        CFRelease(info);
    }
    return result;
}

CFStringRef requirement_with_hashes(CFStringRef base, CFArrayRef hashes) {
    CFMutableStringRef req = CFStringCreateMutableCopy(NULL, 0, base);
    for (CFIndex i = 0; i < CFArrayGetCount(hashes); i++) {
        CFStringAppend(req, CFSTR(" or cdhash H\""));
        CFStringAppend(req, CFArrayGetValueAtIndex(hashes, i));
        CFStringAppend(req, CFSTR("\""));
    }

    // It has to compile here, or amfid would silently keep the old one.
    SecRequirementRef parsed = NULL;
    OSStatus st = SecRequirementCreateWithString(req, kSecCSDefaultFlags, &parsed);
    if (st != errSecSuccess) {
        fprintf(stderr, "error: the requirement does not compile (%d)\n", (int)st);
        exit(1);
    }
    CFRelease(parsed);
    return req;
}

bool valid_hashes(CFArrayRef hashes) {
    if (!hashes || CFGetTypeID(hashes) != CFArrayGetTypeID()) return false;
    for (CFIndex i = 0; i < CFArrayGetCount(hashes); i++) {
        CFTypeRef value = CFArrayGetValueAtIndex(hashes, i);
        if (CFGetTypeID(value) != CFStringGetTypeID()) return false;
        CFStringRef hash = value;
        CFIndex length = CFStringGetLength(hash);
        if (length < 2 || length > 128 || length % 2) return false;
        for (CFIndex j = 0; j < length; j++) {
            UniChar c = CFStringGetCharacterAtIndex(hash, j);
            if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) return false;
        }
    }
    return true;
}
