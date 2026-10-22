/*
 * vphoned_unlock — turn the guest display on.
 *
 * SpringBoardServices' SBSUndimScreen lights the display without the toggle a
 * power-key press has. It is the same call icli's `wake` uses, and needs no
 * entitlement. Getting past the Lock Screen itself is a Home press, driven
 * from Swift (GuestScreenUnlock).
 *
 * The symbol is resolved at run time, so a base without it still starts and
 * the call reports false instead.
 */

#import "Include/VphonedNative.h"

#include <dlfcn.h>

bool vp_screen_undim(void) {
    static void *handle;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        handle = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_NOW);
    });
    void (*undim)(void) = handle ? dlsym(handle, "SBSUndimScreen") : NULL;
    if (!undim) return false;
    undim();
    return true;
}
