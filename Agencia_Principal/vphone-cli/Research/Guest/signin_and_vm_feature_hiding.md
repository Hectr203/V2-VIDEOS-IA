# Hiding Apple-ID sign-in surfaces and VM-unavailable features

Feasibility study (2026-10-07) on an iOS 27.0 guest (iPhone17,3, 24A435), never
signed in, no Apple ID. Two questions:

1. Can every Apple-ID / iCloud sign-in surface across the system apps be hidden?
2. For features the VM does not provide, can the matching Settings entry be hidden?

Static analysis of the 27.0 dyld shared cache
(`/private/tmp/va-analysis/dsc27/24A435__iPhone17,3/dyld_shared_cache_arm64e`),
app binaries extracted from the IPSW, `Preferences.bin`, and the guest device
tree. Companion to `settings_app_row_hiding.md` (the SwiftUI Settings-row binary
patch, a separate work-stream) and `post_setup_signin_and_appstore.md`.

## The one finding that shapes everything: ENTRY ≠ SHEET

The sign-in **sheet** (the credential UI) is drawn **out of process** by remote
view-service apps (`AuthKitUIService.app`, `AppleIDSetupUIService.app`,
`AAUIViewService.app`, `AMSUIAuthenticationViewService`, `StoreKitUIService.app`,
`GameCenterUIService.app`). An app only hosts it. So:

- **Suppressing the shared sign-in machinery kills the *sheet*** — tapping any
  "Sign in" does nothing — **but does not remove the *entry* banner/cell** the
  app itself draws. The banner stays; it just becomes inert.
- **Removing the entry** (the banner/row the user sees) is per-app work, except
  where the entry *is* an embedded shared controller (Settings' Apple-Account
  card; the App Store account tab) — those vanish with the sheet hook.

And there are **two independent shared sheet paths**, not one:

| Path | Frameworks | Used by |
| --- | --- | --- |
| Apple-ID / iCloud | AuthKit, AuthKitUI, AppleAccountUI (`AAUISignInController`, `AKAppleIDAuthenticationController`, `AKTapToSignInViewController`) | Settings card, Find My, Fitness, Freeform, Home, FaceTime, Mail(iCloud), Game Center |
| **Media & Purchases (store)** | **`AMSUIAuthenticationViewService` + `StoreKitUIService`** (brokered by StoreKit) | **Music, TV, Podcasts, Books, App Store, iTunes Store, News** |

A hook that only covers AuthKit/AppleAccountUI **misses the "Sign in to iTunes
Store / Media & Purchases" sheet** — the store path needs its own hook.

## Sign-in SHEET suppression — BUILT and verified (`libsigninfix.dylib`)

Shipped as `libsigninfix.dylib` (`VPhoneGuestComponents/SignInFix/libsigninfix.m`),
loaded by SystemHook into **app processes only** (`vpIsAppPath`, never daemons, so
background AuthKit auth is untouched); wired into `VPhoneGuestEnvironment.libraries`,
`GuestAPI+Environment.environmentLibraries`, `StageBundle.sh` and `ValidateBundle.sh`
like the other hook dylibs. Resolves every class+selector by name at load (the
`libhapticsfix` pattern); re-runs on `_dyld_register_func_for_add_image` so the
lazily-loaded frameworks (AuthKitUI, AppleIDSetupUI, GameCenterUI, AMSUI) get
hooked when they map. Verified on `signintest-iphone27` (iOS 27.0, iPhone17,3).

**The iOS 27 reality that the earlier plan got wrong.** The Settings "Apple
Account" card does **not** present a plain ObjC `AAUISignInController`, and
`prepareInViewController:completion:` is **not** the seam. Tapping the card
presents a **SwiftUI `.sheet`**: a `_TtGC7SwiftUI29PresentationHostingControllerVS_7AnyView_`
is presented through the normal UIKit present funnels, and the real controller —
`AppleIDSetupUI.SignInOptionsViewController` (the "Choose the method to sign
in… / Use Another Apple Device / Sign in Manually" chooser), wrapped by
`AppleIDSetupUI.NavigationControllerReader.Reader<…SignInOptionsViewWrapper…>` —
is a **SwiftUI-hosted child that is not attached to the host when `present:` is
called**. So a present-time block sees only the opaque `AnyView` host and cannot
decide. (Confirmed by logging all present funnels + `loadViewIfNeeded`: the host
always logged "pass".)

iOS 27's UIKit present funnels, for reference (from a runtime
`class_copyMethodList` dump): the public `presentViewController:animated:completion:`
→ `_presentViewController:animated:completion:` →
`_presentViewController:withAnimationController:completion:` → the lowest funnel
`_presentViewController:modalSourceViewController:presentationController:animationController:interactionController:handoffData:completion:`.
(The older guessed `_presentViewController:withAnimationController:interactionController:completion:`
does **not** exist on 27.)

**What the dylib actually does (two seams):**

| Hook | Covers |
| --- | --- |
| swizzle `-[UIViewController presentViewController:animated:completion:]` **and** the lowest funnel `_presentViewController:modalSource…:handoffData:completion:` → drop the present when the presented controller, or a UIKit child one–three levels in, is a sign-in controller | plain-UIKit sign-in sheets: the AuthKitUI `AK*`/`AAUI*` modal controllers, Game Center's `GKSignInViewController` |
| own-method swizzle `-[AppleIDSetupUI.SignInOptionsViewController viewWillAppear:]` → hide its view, then `dismissViewControllerAnimated:NO` the presenting sheet on the next tick | the Settings SwiftUI "Apple Account" sheet (the present seam can't reach it) |
| no-op `+[AMSAuthenticationViewServiceLauncher launchWithClientInfo:action:xpcEndpoint:]` | the out-of-process "Media & Purchases" store sheet |
| no-op `authenticationShowSignInUIForLocalPlayer:origin:dismiss:` on `GKLocalPlayer` and `_TtC12GameCenterUI34LocalPlayerAuthenticationPresenter` | in-game Game Center sign-in (belt; the present seam also catches `GKSignInViewController`) |

Recognition is name-based (`kSignInVCClasses` + strong substrings `SignIn`,
`AppleIDSetup`, `TapToSignIn`, `DeviceToDevice`, …), so new sign-in classes are
caught without new addresses. The own-method swizzle uses `class_addMethod`-first
so it overrides **only** `SignInOptionsViewController`, never a shared superclass.

**Known limitation (characterised, not a bug).** For the SwiftUI Settings sheet
the block is a *dismiss-as-it-appears*, not a *never-present*: the sheet is torn
down before it finishes animating in, so a **blank panel flashes** (the content
view is hidden first, so the sign-in chooser itself is never shown). The
present-seam block for plain-UIKit sheets *is* a clean never-present.

A truly zero-flicker kill of that one card means **hiding the row**, not blocking
the sheet — and the lever is **not** an MDM restriction. Live RE (see
`settings_app_row_hiding.md:30-40`) proved the `primaryAppleAccount` card
consults **no** ManagedConfiguration feature: on root render Settings queries
only `allowBluetoothModification` and `allowWritingTools`, never
account-modification. `allowAccountModification` / `MCFeatureAccountModificationAllowed`
gates the **Setup Assistant** Apple-ID pane (`setup_assistant_pane_gating.md`),
not this card, and there is no supervision-free restriction (and no
`applyRestrictionDictionary:` helper in-repo) that hides it. The card is produced
by the pure-Swift provider `_TtC11SettingsApp35PrimaryAppleAccountListItemProvider`,
bound to account availability, not to a restriction. The one lever that cleanly
removes the row (verified durable across reboot) is the existing **Preferences
binary patch** `cfw patch-settings-root-rows` (patch `system-preferences-exp-root_rows`,
`CustomFirmwareSettingsRows.swift`), which forces that provider Optional empty —
the Settings-row work-stream, not this dylib.

**Store / Game Center hooks — verified present.** On `signintest-iphone27`,
os_log confirmed the hooks install in the relevant processes:
`+[AMSAuthenticationViewServiceLauncher launchWithClientInfo:action:xpcEndpoint:]`
in Settings, Music and Games; and both Game Center seams
(`-[GKLocalPlayer authenticationShowSignInUIForLocalPlayer:origin:dismiss:]` and
`-[_TtC12GameCenterUI34LocalPlayerAuthenticationPresenter authenticationShowSignInUIForLocalPlayer:origin:dismiss:]`)
in the Games app. The interactive store/Game-Center sheets could not be
force-triggered on a signed-out, content-less guest (the apps do silent
background token auth and sit in onboarding), but the no-ops are confirmed
in place and will fire when those methods are invoked. libsigninfix emits one
`installed …` os_log line per hook per process for this observability.

**What this does and does not do:** it makes the sign-in flows inert guest-wide
(one small dylib). It does **not** remove the entry banners — see below. There is
**no** shared "sign-in unavailable" flag to flip to hide banners: they render
*because* no account exists, and faking an account is disallowed (AuthKit's
`shieldSignInOrCreateFlows` is age/teen-attestation-specific, not a device "no
sign-in" switch, and triggers its own replacement UI).

**Deploy on a sealed-APFS guest:** `env.install`/the fast loop live-writes
`/usr/lib`, but new launches load the sealed snapshot and a reboot reverts the
live write — so an existing-lib update does **not** take that way. Use
`vphone-launchpad-cli bundle install-local <bundle> --keep-default` then
`vphone-launchpad-cli vm set-bundle <vm> <version> --update-environment` (VM
stopped), which bakes the dylib into the snapshot through the helper.

## Sign-in ENTRY (banner/cell) removal — per-app, uneven

| App | Entry point | Entry UI | How to hide the ENTRY |
| --- | --- | --- | --- |
| App Store, TV, FaceTime, Messages, News, iTunes Store, Camera, Home | various | — | **Removable** (the simplest hide; already removed on the guest) |
| Settings "Apple Account" card | top card | SwiftUI `.sheet` hosting `AppleIDSetupUI.SignInOptionsViewController` (NOT ObjC `AAUISignInController`) | **sheet made inert** by `libsigninfix` (dismiss-as-appears, blank flash); a zero-flicker hide is the Preferences row binary patch `system-preferences-exp-root_rows` (other work-stream) — **not** MDM (the card consults no managed-config feature) |
| Game Center (in-game) | `GKLocalPlayer.authenticate` sheet | GameCenterUIService (ObjC) | **covered by the sheet hook** |
| **Mail** | `OBWelcomeController` "Welcome to Mail" → AccountsUI iCloud row | **ObjC/UIKit** | **easy ObjC hook** — swizzle the OBWelcome path or drop iCloud/Apple from the AccountsUI account-type list |
| **Books** | store "Account / Sign In" cell | **ObjC** `BK*` store controllers | **easy ObjC hook** on the `BK*` controllers |
| **Find My** | full-screen **sign-in wall on launch** | SwiftUI | **binary patch** — highest value (hard gate), removable |
| **Fitness** | **iCloud sign-in page on launch** | SwiftUI (FitnessUI) | **binary patch** — highest value (hard gate), removable |
| Freeform | "Sign in to iCloud to use Freeform" use-gate | SwiftUI | binary patch (removable) |
| Music | account button + soft "Media & Purchases" prompts | SwiftUI (MusicKit) | binary patch (removable); soft, not a gate |
| Photos | `SIGN_INTO_ICLOUD` upsell banner (deep-links to Settings) | SwiftUI | binary patch; soft banner |
| Health | iCloud-sync upsell cell | SwiftUI | binary patch; soft |
| Podcasts | "View Apple Account" cell | SwiftUI | binary patch (removable); soft |
| Wallet | — (no Apple-ID sign-in banner; only Apple-Pay onboarding) | ObjC thin | **nothing to hide** |
| Camera | — (no Apple-ID entry at all) | — | nothing to hide |

**Net for entries:** 8 apps handled by *removal*; 2 (Settings card, Game Center)
by the sheet hook / Settings patch; Wallet/Camera have none; the real per-app
work is **2 easy ObjC swizzles (Mail, Books)** and **7 SwiftUI binary patches**,
of which **Find My and Fitness** are the only hard launch gates (do these first
if the SwiftUI route is pursued).

## VM-unavailable features → Settings rows

**The lever is the device tree, not `libmisfix`.** `libmisfix` is not injected
into Settings, and dyld `__interpose` does not reach MobileGestalt calls made
from inside the shared cache (where the `SettingsApp` providers run). Instead,
the guest's device-tree `/product` leaves hardware properties as `syscfg/xxxx`
placeholders, **MobileGestalt reads a placeholder as absent**, and Settings'
`gestalt` visibility rules drop the row for free. This already works and is
maintained by the `cfw` device-tree patchers (`DeviceTreeGuestDevicePatches.swift`,
`CustomFirmwarePostRestoreDeviceTree.swift`). Settings' rule kinds (from
`Preferences.bin` `SettingsSidebarListItemVisibilityRule`): `gestalt`,
`biometricKitIsUnavailable`, `restrictedByManagedConfigurationFeature`,
`applicationRestricted`, `featureFlag`, `boolean`, `pluginExists`, `sharedPad`,
`personaEnrollmentIsDisabled`.

Guest hardware (live device tree): present = `bluetooth`, `sep`, `isp`/`ispRtb`;
**absent** = baseband/modem, NFC/stockholm, UWB/Rose, wifi-chipset, biometric
(Pearl/Mesa).

| Feature | Settings row | Status | Action |
| --- | --- | --- | --- |
| Cellular / mobile data | `com.apple.settings.cellular` | **already hidden** (no baseband) | none |
| Personal Hotspot | `com.apple.settings.personalHotspot` | **already hidden** | none |
| Carrier / SIM / eSIM | (under Cellular) | **already hidden** | none |
| Satellite / SOS-via-satellite | `com.apple.settings.satellite` | **already hidden** | none (Emergency SOS root row stays — baseline) |
| Face ID / Touch ID | `com.apple.settings.passcodeAndBiometrics` | biometric content **auto-gone** (`biometricKitIsUnavailable` → row reads "Passcode") | none (passcode-set is infeasible anyway) |
| NFC / UWB / True Tone / ProMotion / System Haptics | sub-content of various rows | **already absent** | none |
| **Bluetooth** | `com.apple.settings.bluetooth` | **shows** (baseline row, no "no-BT-hw" gate) | **MDM restriction** (`restrictedByManagedConfigurationFeature`) or binary patch |
| **Camera** | `com.apple.settings.camera` | **shows** (device-class cap present) | MDM restriction, or `devicetree-cfw-arm_io_isp_*camera*` caps, or binary patch |
| **AirDrop** | `com.apple.settings.general.airDrop` | **shows** | **MDM restriction** `allowAirDrop` (clean) or binary patch |
| **AirPlay & Continuity** | `…general.airPlayAndContinuity` | **shows** | binary patch / restriction |
| **CarPlay** | `com.apple.settings.general.carPlay` | **shows** | binary patch / restriction |
| Apple Account / iCloud / Wallet & Apple Pay / Game Center / Software Update | account/service rows | **show** (no hardware gate) | **the Settings SwiftUI row patch** (`settings_app_row_hiding.md`, other work-stream) |
| Wi-Fi, Ethernet | `…wifi` / `…ethernet` | show | **do not hide** — networking is functional (virtio-net surfaces here) |
| Emergency SOS, Sounds & Haptics, Passcode | baseline rows | show | do not hide (only their hardware sub-content is/should be suppressed) |

**Clean wins (no work):** cellular, hotspot, carrier, satellite, biometric
content — already auto-hidden by the device-tree capability-absent mechanism;
just keep the device-tree patcher from ever filling those hardware caps.
**Patch-free next tier:** Bluetooth / Camera / AirDrop via ManagedConfiguration
restrictions. **Binary-patch tier (other work-stream):** the account/service
rows and AirPlay/CarPlay.

## Recommended plan

1. **Ship one guest "sign-in suppressor" dylib** (SystemHook `dlopen`, ObjC
   swizzle) covering **both** shared sheet paths — AuthKit/AppleAccountUI **and**
   AMSUI/StoreKitUI, plus GameCenterUI. Highest value, lowest cost: every
   Apple-ID / iCloud / store sign-in flow becomes inert guest-wide. Also fold in
   the two easy ObjC **entry** hooks (**Mail** `OBWelcomeController`/AccountsUI,
   **Books** `BK*` controllers) since they live in the same dylib pattern.
2. **Keep removing the removable apps** (already done) — the cheapest entry hide
   for App Store, TV, FaceTime, Messages, News, iTunes Store, Camera, Home.
3. **VM-feature rows:** rely on the existing device-tree capability-absent
   mechanism (already hides cellular/hotspot/satellite/biometric). Add
   **ManagedConfiguration restrictions** for Bluetooth / Camera / AirDrop
   (patch-free). Leave Wi-Fi/Ethernet/Emergency SOS/Passcode.
4. **SwiftUI entry banners + account/service Settings rows** (Find My, Fitness,
   Freeform, Music, Photos, Health, Podcasts; Apple Account / iCloud / Wallet /
   Game Center / Software Update) need **binary patches** — expensive, and the
   Settings-row half is the separate `settings_app_row_hiding.md` work-stream
   (now unblocked: Ghidra is installed). Prioritise **Find My + Fitness** (hard
   launch gates) if the app-side SwiftUI patching is pursued.

## Artifacts / cross-refs

Scratch (read-only research outputs): `/private/tmp/signin-a1/` (AuthKit /
AuthKitUI / AppleAccountUI / Accounts class dumps + disass), `/private/tmp/signin-a2/`
(per-app binary classification), `/private/tmp/vmfeat-b/` (ioreg + decoded MG
cache). Settings-row binary-patch work (separate session): `settings_app_row_hiding.md`,
`Research/Guest/2026-10-07_reverse-settings-rows-report.md`, `/private/tmp/prefs-audit/`.
Device-tree capability mechanism: `Research/0_binary_patch_comparison.md`
§"An iPhone guest's product description from D47AP".
