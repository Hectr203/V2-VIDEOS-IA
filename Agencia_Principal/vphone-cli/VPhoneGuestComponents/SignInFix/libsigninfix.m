// libsigninfix.m — suppress Apple-ID / iCloud / store sign-in *sheets* on a
// research guest that has no Apple account.
//
// Two kinds of sign-in UI exist, and each needs its own seam:
//
//  1. Plain-UIKit sign-in controllers presented modally (the AuthKitUI sign-in
//     controllers, Game Center's GKSignInViewController, …). We swizzle the
//     public present and the lowest UIKit modal funnel and DROP the present when
//     the presented controller — or a controller nested one or two levels inside
//     it — is a sign-in controller.
//
//  2. The Settings "Apple Account" sheet, which on iOS 27 is a SwiftUI `.sheet`:
//     a _TtGC7SwiftUI29PresentationHostingcontrollerVS_7AnyView_ is presented,
//     and the real controller, AppleIDSetupUI.SignInOptionsViewController, is a
//     SwiftUI-hosted child that is NOT attached when present: is called, so the
//     present seam above cannot see it. For this one we hook the controller's
//     own -viewWillAppear:, hide its view and dismiss the sheet its presenter
//     put up. (The sheet is dismissed before it finishes animating in; what
//     shows is a blank panel, not the sign-in chooser.)
//
//  3. The store "Media & Purchases" sheet is spawned out of process by a view
//     service launcher, which we no-op.
//
// Nothing here touches account state or fakes a signed-in account, and it does
// NOT remove the entry banners (they render because no account exists). See
// Research/Guest/signin_and_vm_feature_hiding.md for the full map.
//
// SCOPE: loaded by SystemHook into app processes only (vpIsAppPath), NOT
// daemons, so background AuthKit auth is untouched.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <os/log.h>
#include <mach-o/dyld.h>

static void vpLog(NSString *message) {
    os_log(OS_LOG_DEFAULT, "VPSignInFix %{public}s", message.UTF8String ?: "(nil)");
}

static NSString *vpClassName(id obj) { return obj ? NSStringFromClass([obj class]) : @"nil"; }

// MARK: - sign-in controller recognition

// Plain-UIKit sign-in controllers to block when presented.
static const char *const kSignInVCClasses[] = {
    "AAUISignInController", "AAUIServiceSignInController", "AAUIOnboardingSignInController",
    "AKModalSignInViewController", "AKSignInViewController", "AKBaseSignInViewController",
    "AKAppleIDSetupViewController", "AKTapToSignInViewController",
    "GKSignInViewController", "GKHostedAuthenticateViewController", NULL,
};

// High-confidence class-name substrings: a controller whose class name contains
// one of these is a sign-in surface even when it is not in the list above (the
// exact class varies by iOS).
static BOOL vpNameStrongSignIn(NSString *name) {
    if (!name) return NO;
    static NSArray *needles;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        needles = @[ @"SignIn", @"AppleIDSetup", @"TapToSignIn", @"AppleAccountSignIn",
                     @"AppleAccountSetup", @"DeviceToDevice", @"AppleIDLogin", @"iCloudLogin" ];
    });
    for (NSString *n in needles)
        if ([name rangeOfString:n].location != NSNotFound) return YES;
    return NO;
}

static BOOL vpVCMatches(id vc) {
    if (!vc) return NO;
    for (int i = 0; kSignInVCClasses[i]; i++) {
        Class c = objc_getClass(kSignInVCClasses[i]);
        if (c && [vc isKindOfClass:c]) return YES;
    }
    return vpNameStrongSignIn(NSStringFromClass([vc class]));
}

// A presented sign-in controller is often wrapped in a navigation/container
// controller; check the controller and a couple of levels of children it has
// already attached (UIKit nav/tab children, not SwiftUI-hosted ones).
static BOOL vpIsSignInVC(id vc, int depth) {
    if (!vc || depth > 3) return NO;
    if (vpVCMatches(vc)) return YES;
    SEL lists[] = { @selector(children), @selector(viewControllers) };
    for (unsigned i = 0; i < 2; i++) {
        if (![vc respondsToSelector:lists[i]]) continue;
        id kids = ((id (*)(id, SEL))objc_msgSend)(vc, lists[i]);
        if ([kids isKindOfClass:[NSArray class]])
            for (id child in (NSArray *)kids)
                if (vpIsSignInVC(child, depth + 1)) return YES;
    }
    return NO;
}

// MARK: - UIViewController presentViewController:animated:completion: (public)
typedef void (*VPPresentIMP)(id, SEL, id, BOOL, id);
static VPPresentIMP gPresentOrig = NULL;
static int gPresent = 0;
static void vp_present(id self, SEL _cmd, id vc, BOOL animated, id completion) {
    if (vpIsSignInVC(vc, 0)) {
        vpLog([NSString stringWithFormat:@"blocked present %@", vpClassName(vc)]);
        if (completion) { void (^c)(void) = completion; c(); }
        return;
    }
    if (gPresentOrig) gPresentOrig(self, _cmd, vc, animated, completion);
}

// MARK: - the lowest iOS 27 modal funnel, for presents that bypass the public
// entry. _presentViewController:modalSourceViewController:presentationController:
//   animationController:interactionController:handoffData:completion:
typedef void (*VPPresentFunnelIMP)(id, SEL, id, id, id, id, id, id, id);
static VPPresentFunnelIMP gPresentFunnelOrig = NULL;
static int gPresentFunnel = 0;
static void vp_presentFunnel(id self, SEL _cmd, id vc, id modalSource, id presentationController,
                             id anim, id interaction, id handoffData, id completion) {
    if (vpIsSignInVC(vc, 0)) {
        vpLog([NSString stringWithFormat:@"blocked present(funnel) %@", vpClassName(vc)]);
        if (completion) { void (^c)(void) = completion; c(); }
        return;
    }
    if (gPresentFunnelOrig)
        gPresentFunnelOrig(self, _cmd, vc, modalSource, presentationController, anim,
                           interaction, handoffData, completion);
}

// MARK: - the Settings SwiftUI "Apple Account" sheet. Its content controller is
// AppleIDSetupUI.SignInOptionsViewController, hosted inside a SwiftUI sheet and
// not reachable at present: time, so we dismiss it as it is about to appear.
typedef void (*VPWillAppearIMP)(id, SEL, BOOL);
static VPWillAppearIMP gSignInWillAppearOrig = NULL;
static int gSignInWillAppear = 0;
static void vp_signinWillAppear(id self, SEL _cmd, BOOL animated) {
    vpLog([NSString stringWithFormat:@"dismissing %@", vpClassName(self)]);
    // Hide the content before it is drawn, so the sheet that briefly slides in
    // while we dismiss is a blank panel, not the sign-in chooser.
    @try {
        id view = ((id (*)(id, SEL))objc_msgSend)(self, @selector(viewIfLoaded));
        if (view) ((void (*)(id, SEL, BOOL))objc_msgSend)(view, @selector(setHidden:), YES);
    } @catch (__unused NSException *e) {}
    if (gSignInWillAppearOrig) gSignInWillAppearOrig(self, _cmd, animated);
    id presenting = ((id (*)(id, SEL))objc_msgSend)(self, @selector(presentingViewController));
    if (presenting) {
        dispatch_async(dispatch_get_main_queue(), ^{
            ((void (*)(id, SEL, BOOL, id))objc_msgSend)(
                presenting, @selector(dismissViewControllerAnimated:completion:), NO, nil);
        });
    }
}

// MARK: - AppleMediaServices: the out-of-process "Media & Purchases" store sheet
// +[AMSAuthenticationViewServiceLauncher launchWithClientInfo:action:xpcEndpoint:]
// is the one ObjC class method that spawns the store sign-in sheet app. No-op.
static id vp_amsLaunchNoop(id self, SEL _cmd, id clientInfo, id action, id xpcEndpoint) {
    (void)self; (void)_cmd; (void)clientInfo; (void)action; (void)xpcEndpoint;
    vpLog(@"blocked AMSAuthenticationViewServiceLauncher");
    return nil;
}
static int gAMSLaunch = 0;

// MARK: - Game Center: the in-process sign-in sheet presenter (belt; the present
// swizzle also catches the GKSignInViewController it would show).
static void vp_gkAuthShowNoop(id self, SEL _cmd, id player, unsigned long long origin, id dismiss) {
    (void)self; (void)_cmd; (void)player; (void)origin; (void)dismiss;
    vpLog(@"blocked GKLocalPlayer authenticationShowSignInUIForLocalPlayer");
}
static int gGKAuthShow = 0;
static int gGKAuthShowSwift = 0;

// MARK: - swizzle helpers

static void vpSwizzle(const char *className, const char *selName, IMP imp,
                      int *installed, IMP *saveOrig) {
    if (*installed) return;
    Class cls = objc_getClass(className);
    if (!cls) return;
    SEL sel = sel_registerName(selName);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    if (saveOrig) *saveOrig = method_getImplementation(m);
    method_setImplementation(m, imp);
    *installed = 1;
    vpLog([NSString stringWithFormat:@"installed -[%s %s]", className, selName]);
}

static void vpSwizzleClassMethod(const char *className, const char *selName, IMP imp, int *installed) {
    if (*installed) return;
    Class cls = objc_getClass(className);
    if (!cls) return;
    SEL sel = sel_registerName(selName);
    Method m = class_getClassMethod(cls, sel);
    if (!m) return;
    method_setImplementation(m, imp);
    *installed = 1;
    vpLog([NSString stringWithFormat:@"installed +[%s %s]", className, selName]);
}

// Override an instance method on exactly `className`, never on a shared
// superclass: if the class does not implement the selector itself,
// class_addMethod installs our override and the saved original is the inherited
// IMP to chain to; otherwise we swap the class's own IMP. `className` may be a
// Swift "Module.Class" name. Used for the leaf sign-in controller.
static void vpSwizzleOwn(const char *className, const char *selName, IMP imp,
                         IMP *saveOrig, int *installed) {
    if (*installed) return;
    Class cls = NSClassFromString([NSString stringWithUTF8String:className]);
    if (!cls) cls = objc_getClass(className);
    if (!cls) return;
    SEL sel = sel_registerName(selName);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    IMP orig = method_getImplementation(m);
    if (class_addMethod(cls, sel, imp, method_getTypeEncoding(m))) {
        if (saveOrig) *saveOrig = orig;
    } else {
        IMP prev = method_setImplementation(class_getInstanceMethod(cls, sel), imp);
        if (saveOrig) *saveOrig = prev;
    }
    *installed = 1;
    vpLog([NSString stringWithFormat:@"installed(own) -[%s %s]", className, selName]);
}

static void vpInstall(void) {
    vpSwizzle("UIViewController", "presentViewController:animated:completion:",
              (IMP)vp_present, &gPresent, (IMP *)&gPresentOrig);
    vpSwizzle("UIViewController",
              "_presentViewController:modalSourceViewController:presentationController:animationController:interactionController:handoffData:completion:",
              (IMP)vp_presentFunnel, &gPresentFunnel, (IMP *)&gPresentFunnelOrig);
    vpSwizzleOwn("AppleIDSetupUI.SignInOptionsViewController", "viewWillAppear:",
                 (IMP)vp_signinWillAppear, (IMP *)&gSignInWillAppearOrig, &gSignInWillAppear);
    vpSwizzleClassMethod("AMSAuthenticationViewServiceLauncher",
                         "launchWithClientInfo:action:xpcEndpoint:",
                         (IMP)vp_amsLaunchNoop, &gAMSLaunch);
    vpSwizzle("GKLocalPlayer", "authenticationShowSignInUIForLocalPlayer:origin:dismiss:",
              (IMP)vp_gkAuthShowNoop, &gGKAuthShow, NULL);
    vpSwizzle("_TtC12GameCenterUI34LocalPlayerAuthenticationPresenter",
              "authenticationShowSignInUIForLocalPlayer:origin:dismiss:",
              (IMP)vp_gkAuthShowNoop, &gGKAuthShowSwift, NULL);
}

// Frameworks (AuthKitUI, AppleIDSetupUI, GameCenterUI, AMSUI) load lazily; keep
// installing until each class it owns has been hooked.
static void vpImageAdded(const struct mach_header *header, intptr_t slide) {
    (void)header; (void)slide;
    if (!gPresent || !gPresentFunnel || !gSignInWillAppear || !gAMSLaunch ||
        !gGKAuthShow || !gGKAuthShowSwift) vpInstall();
}

__attribute__((constructor)) static void vpInitialize(void) {
    vpInstall();
    _dyld_register_func_for_add_image(vpImageAdded);
}

int vphone_signinfix_version(void) { return 8; }
