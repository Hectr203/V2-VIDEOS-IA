// libprefsfix.m — hide the CoreFollowUp suggestion/upsell groups in Settings.
//
// A research guest has no Apple account, so the follow-up "suggestions" Settings
// surfaces are all sign-in / purchase / upsell prompts: "Apple Account
// Suggestions" (`com.apple.followup.group.account`), "Services Included with
// Purchase" (`.services`), "Add AppleCare Coverage" (`.ndo`), "More for Your
// iPhone" (`.device`), "Updates to Your Screen Time" (`.screentime`). They are
// driven by CoreFollowUp, which Settings reads through the category method
// -[FLTopLevelViewModel sapp_groupsWithQueue:completion:] ("FL" = FollowUp).
//
// This hook swizzles that method and forwards an empty group array to Settings'
// completion, so none of the follow-up groups are shown. Settings' own root
// list (account banner, General, …) is built by the SwiftUI SettingsApp module
// and is untouched by this — see Research/Guest/settings_app_row_hiding.md.
//
// SystemHook dlopens this into com.apple.Preferences only (vpIsPreferences),
// the same route it uses for libhapticsfix in SpringBoard. It swizzles rather
// than interposes, because Preferences' framework classes live in the dyld
// shared cache, which dyld interposing does not rebind.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <os/log.h>
#import <dlfcn.h>
#include <mach-o/dyld.h>

#define VP_CORE_FOLLOWUP \
    "/System/Library/PrivateFrameworks/CoreFollowUp.framework/CoreFollowUp"

static void vpLog(NSString *message) {
    os_log(OS_LOG_DEFAULT, "VPPrefsFix %{public}s", message.UTF8String ?: "(nil)");
}

typedef void (*VPGroupsIMP)(id, SEL, id, id);
static VPGroupsIMP vpOriginalGroups = NULL;

// Settings asks the FollowUp model for its groups, then renders them. Forward an
// empty array to the completion so no follow-up group reaches the UI. The
// original is still called so the model runs its own work unchanged.
static void vpHiddenGroups(id self, SEL _cmd, id queue, id completion) {
    void (^forward)(id) = completion;
    void (^wrapper)(id) = ^(id groups) {
        if (forward)
            forward(@[]);
    };
    if (vpOriginalGroups)
        vpOriginalGroups(self, _cmd, queue, wrapper);
}

static void vpInstall(void) {
    if (vpOriginalGroups)
        return;
    Class model = objc_getClass("FLTopLevelViewModel");
    if (!model)
        return;
    SEL selector = sel_registerName("sapp_groupsWithQueue:completion:");
    Method method = class_getInstanceMethod(model, selector);
    if (!method) {
        vpLog(@"sapp_groupsWithQueue:completion: not found");
        return;
    }
    vpOriginalGroups = (VPGroupsIMP)method_getImplementation(method);
    method_setImplementation(method, (IMP)vpHiddenGroups);
    vpLog(@"follow-up groups hidden");
}

// CoreFollowUp may not be loaded yet when the constructor runs; install when its
// class appears.
static void vpImageAdded(const struct mach_header *header, intptr_t slide) {
    (void)header;
    (void)slide;
    if (!vpOriginalGroups && objc_getClass("FLTopLevelViewModel"))
        vpInstall();
}

__attribute__((constructor)) static void vpInitialize(void) {
    dlopen(VP_CORE_FOLLOWUP, RTLD_LAZY | RTLD_LOCAL);
    vpInstall();
    if (!vpOriginalGroups)
        _dyld_register_func_for_add_image(vpImageAdded);
}

int vphone_prefsfix_version(void) { return 1; }
