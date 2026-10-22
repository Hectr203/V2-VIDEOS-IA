## Current verified state — 2026-10-07

All five requested rows are hidden on panetest and passed rollback/reapply/full-reboot checks. Indexing is excluded. Both Preferences and Software Update cache patch implementations are now in the installer catalogue, standard-blocked and reversible. 52 tests and the complete CLI build pass. No new Bundle was published. See [final report](2026-10-07_reverse-settings-rows-report.md). Older sections below record superseded experiments and blockers.

# Hiding rows in Settings.app with a userland hook

Goal: on a research guest, hide the sign-in / suggestion / update surfaces that
remain in Settings — the "Apple Account — Sign in…" banner, the CoreFollowUp
suggestion/upsell groups, the "Software Update" row, and the "Optimising Search
and Siri" row. Prototyped live on 2026-10-06 on `panetest-iphone` (iPhone17,3
iOS 27.0, bundle 2.6.0-local.92448989), by injecting a probe dylib into
`com.apple.Preferences`. Static analysis of the 27.0 Preferences binary
(`/private/tmp/setupres/Preferences.bin`).

## TL;DR

- **Injecting a dylib into Settings needs no bootstrap.** The shipped
  launchd→launchdhook→`DYLD_INSERT_LIBRARIES`→SystemHook chain already injects
  `libbatteryhealthfix.dylib` into `/Applications/Preferences.app/Preferences`.
  A new `libprefsfix.dylib` ships the same way. Verified: probe injected, ObjC
  swizzle ran, `os_log` captured, Settings stayed healthy.
- **Cleanly hookable (ObjC): the CoreFollowUp suggestion groups.**
  `-[FLTopLevelViewModel sapp_groupsWithQueue:completion:]` ("FL" = FollowUp) is
  an ObjC category method in the Preferences binary; swizzling it and forwarding
  an empty array hides `followup.group.{account,services,ndo,device,screentime}`
  — "Apple Account Suggestions", "Services Included with Purchase", "Add
  AppleCare Coverage", "More for Your iPhone", "Updates to Your Screen Time".
  (These are empty on a guest whose `appleidsetupd` is already disabled —
  `post_setup_signin_and_appstore.md` — so hiding them is belt-and-suspenders.)
- **NOT cleanly hookable — needs a binary patch: the Apple Account banner, the
  Software Update row, the "Optimising Search and Siri" row.** These are built
  by the SwiftUI `SettingsApp` module, which is **stripped of Swift symbols**
  (`nm` shows only ObjC class metadata, no provider methods), and the account
  item's content comes from `SettingsHost.NavigationHost.primaryAppleAccount` in
  the dyld shared cache. There is no ObjC method to swizzle. The Setup.app gate
  `-[MCProfileConnection effectiveBoolValueForSetting:]` (account modification)
  does **not** apply: Settings never queries it for the banner (on root render
  it asked only `allowBluetoothModification` and `allowWritingTools`).
- **Decision (2026-10-06): hook the FollowUp groups + (TBD) Software Update;
  binary-patch the Preferences executable for the Apple Account banner.**

## Injection (proven)

`vphone-launchdhook-spawn.log` on the guest shows, for every launch:

```
event=inserted+batteryhealthfix child=1586 path=/Applications/Preferences.app/Preferences status=0
```

so Preferences runs with
`DYLD_INSERT_LIBRARIES=/usr/lib/SystemHook-vphone.dylib:/usr/lib/libbatteryhealthfix.dylib`.
A probe built as `libbatteryhealthfix.dylib` (arm64e, ad-hoc signed, pushed over
`files.write` + `environment.install`, Preferences killed to remap) loaded,
swizzled, and logged. Two gotchas:

- **Settings is sandboxed**: it cannot write `/var/mobile/Library/Caches/…`
  (SpringBoard/HapticsFix can). Log via `os_log(OS_LOG_DEFAULT,
  "...%{public}s", …)` and read with `logs.syslog`; `%@`/`NSLog` dynamic args
  come back `<private>`, so force `%{public}s` with a C string.
- Build flags (HapticsFix pattern): `xcrun --sdk iphoneos clang -arch arm64e
  -miphoneos-version-min=26.0 -Os -fobjc-arc -dynamiclib -framework Foundation
  -Wl,-not_for_dyld_shared_cache`, then `codesign --force --sign -`.

Swizzle template (HapticsFix / CamFix): `dlopen` the defining framework if
needed, `class_getInstanceMethod` → save `method_getImplementation` → install
with `method_setImplementation`; install from a `__attribute__((constructor))`
and fall back to `_dyld_register_func_for_add_image` if the class is not yet
registered. Use **ObjC swizzling, not `__interpose`** — Preferences framework
classes live in the shared cache, which interposing does not rebind.

## The FollowUp group hider (works)

`FLTopLevelViewModel` is CoreFollowUp's model. The Settings-app category method
`-[FLTopLevelViewModel sapp_groupsWithQueue:(id)queue completion:(void(^)(NSArray *groups))completion]`
builds the follow-up section. Swizzle it, call the original with a wrapper
completion, and forward `@[]`:

```objc
static void vpMySappGroups(id self, SEL _cmd, id queue, id completion) {
    void (^real)(id) = completion;
    void (^wrap)(id) = ^(id groups) { if (real) real(@[]); };   // drop all follow-up groups
    gOrigGroups(self, _cmd, queue, wrap);
}
```

Observed groups before filtering (iOS 27, class `FLGroupViewModelImpl`, each has
`-identifier`/`-rowTitle`): `com.apple.followup.group.account` ("Apple Account
Suggestions"), `.services` ("Services Included with Purchase"), `.none`,
`.screentime` ("Updates to Your Screen Time"), `.device` ("More for Your
iPhone"), `.ndo` ("Add AppleCare Coverage"). Forwarding `@[]` left Settings
healthy (screenshot: root list intact, no follow-up cards). To drop only some,
filter by `-identifier` instead of returning `@[]`.

## The Apple Account banner — binary patch (chosen route)

The banner is `SettingsSidebarListAppleAccountLink` / `PrimaryAppleAccountLinkModel`,
produced by `_TtC11SettingsApp35PrimaryAppleAccountListItemProvider` (Swift,
`_TtCs12_SwiftObject`, no ObjC methods). `nm` on Preferences.bin has no defined
Swift symbol for it — the module is stripped — and the only account symbols are
imports (`SettingsHost.NavigationHost.primaryAppleAccount`,
`ACAccountTypeIdentifierAppleAccount`, `AAAppleAccountInformationCache`). So the
patch has to be found by **string anchors + xref**, the repo's standard
patcher technique (`FirmwarePatcher`: string anchors, ADRP+ADD xrefs, no
hardcoded offsets):

1. Find the cstrings `PrimaryAppleAccountLinkModel` /
   `SettingsSidebarListAppleAccountLink` in Preferences.bin, and their ADRP+ADD
   xrefs.
2. The referencing function is the sidebar-item builder that appends the account
   link to the root list. Identify where it conditionally adds the account item.
3. Patch that site so the account item is never appended (make the producing
   call return empty / skip the append), leaving the rest of the sidebar intact.
   Shape-verify with Capstone before writing (guardrails), `retab` not `ret`.
4. Ship as a guest-executable patch of `/Applications/Preferences.app/Preferences`
   (the same `cfw`/environment flow the Setup.app pane patch uses —
   `setup_assistant_pane_gating.md`), `.bak` beside it, ad-hoc re-sign.

The Software Update row and "Optimising Search and Siri" row are the same kind
of SwiftUI item (`GeneralSettingsListItemProvider`,
`IndexingProgressListItemProvider`); if they are not reachable by a cleaner hook
they fold into the same Preferences binary patch. (The Software Update row lives
under General, a sub-list — confirm whether General is still a `PSListController`
pane, in which case `-[PSListController specifiers]` is an ObjC hook that can
filter the row without a patch.)

### Binary-patch RE findings (2026-10-06) — no clean anchor to the inclusion decision

Full `__TEXT.__text` disassembly of `Preferences.bin` (`ipsw macho disass -x`,
string markup) gives exactly four xref regions for the account anchors, and
**none is the point where the account item is added to the sidebar**:

| Addr | What it is | Patchable to hide? |
| --- | --- | --- |
| `0x100021d08` | `SettingsSidebarListItemIdentifier` **rawValue switch** (enum case → `"com.apple.settings.primaryAppleAccount"`); it sits in a huge switch beside every other identifier (`people`, `bluetooth`, `followUp*`, …) | No — only renames the identifier string; the item still renders |
| `0x1000a914c` | A **navigation-destination `==` / routing** chain (`SettingsHost.NavigationHost.primaryAppleAccount` compared via `Equatable.==`, returns an index) | No — routing, not inclusion |
| `0x100044404`–`0x1000459d4` | The account link's **SwiftUI `body`** (`SwiftUI.LazyState`, `HorizontalAlignment.leading`, `LabelGroup`; the `.swift` string is only an async-executor assert) | No — patching the view breaks rendering, doesn't remove the row |
| `0x100052168`, `0x100086a1c` | The account **state/status** logic (`aa_primaryAppleAccount` → `aa_isSuspended`/`aa_isPrimaryEmailVerified`/`aa_suspensionInfo`/`isiCloudSuspended`; builds enum cases `primaryAppleAccountSignIn`, `supervisedDevice`) | No — decides *what* status to show, not *whether* to show |

The sidebar item is added by the `SettingsSidebarListItemIdentifier.primaryAppleAccount`
**enum case** — an integer tag, so its construction site carries no string and
no symbol (the `SettingsApp` module is stripped). Finding the append/condition
therefore needs data-flow from the enum tag, not a string anchor — i.e. a
Swift-aware decompiler (Hopper/IDA/Ghidra+Swift), not raw `ipsw` disassembly.

**r2 follow-up (2026-10-06):** the only RE tools on the build machine are
`radare2` (disassembler; no r2ghidra/decompiler plugin) and `ipsw`/Capstone —
no Ghidra/Hopper/IDA. r2 recovers the account *classes* from Swift metadata
(`SettingsApp.PrimaryAppleAccountListItemProvider` = swift class 107 /
objc class 198, `SettingsSidebarListAppleAccountLink` = 108,
`PrimaryAppleAccountLinkModel` = 106) but **not their methods** (pure Swift,
protocol-witness, stripped), and `/r` reference searches to the account type
metadata records return nothing (construction goes through accessors / is
inlined). So even with r2, the append site is not reachable without a
Swift-aware **decompiler**, which this machine does not have.

**Assessment:** a reliable guest-executable patch of the banner is **high-effort
/ low-tractability with the tooling in this repo** (Capstone decode only, no
Swift decompiler). This vindicates the original "recommended against" note.
Realistic options: (a) leave the banner (it is an inert "Sign in" prompt) and
ship only the clean FollowUp-group hook; (b) pinpoint the append with a Swift
decompiler offline, then patch the single site; (c) a fragile view-body patch
that renders the account cell empty (leaves a blank row — not recommended).

## Shipping a new hook component (`libprefsfix.dylib`)

Follows `libbatteryhealthfix` exactly (both target only Preferences):

1. `VPhoneGuestComponents/PrefsFix/libprefsfix.m` (the swizzle).
2. `VPhoneGuestComponents/Makefile`: a target mirroring `BATTERYHEALTHFIX`
   (`-install_name /usr/lib/libprefsfix.dylib`, `-lobjc`,
   `-Wl,-not_for_dyld_shared_cache`, `codesign --force --sign -`), add to
   `ARTIFACTS` and the stage-dir rule.
3. `VPhoneExecutable/VPhoneVirtualization/Build/StageBundle.sh`: copy into
   `Contents/Resources/guest-resources`.
4. `VPhoneExecutable/VPhoneVirtualization/Build/ValidateBundle.sh`: add to the
   `require_signed_macho` list (or the bundle seal fails).
5. `VPhoneKit/VPhoneCoreKit/VirtualMachine/VPhoneGuestEnvironment.swift` **and**
   `VPhoneDaemon/Daemon/GuestAPI+Environment.swift`: add the name to both
   library lists (they must match; `environment.install` rejects unlisted names).
6. **`VPhoneGuestComponents/SystemHook/SystemHook-vphone.c`** (the approach
   actually used): `libprefsfix` only swizzles (no interpose), so it does **not**
   need the DYLD_INSERT slot — SystemHook `dlopen`s it into Preferences from its
   constructor, exactly as it does `libhapticsfix` into SpringBoard. Added
   `vpIsPreferences(path)` (suffix `/Preferences.app/Preferences`) and
   `if (vpIsPreferences(path)) vpLoadLibrary("prefs-fix", VP_PREFS_FIX);` before
   the app gate. This avoids any change to the launchd/all-process env-building
   core (`InjectionEnvironment.h` / `vpInsertHooks`) — the lower-risk path. The
   multi-extra DYLD_INSERT alternative was not needed.

Iteration without a bundle rebuild (once the name is in both Swift lists and on
the guest): `files.write` the dylib (base64) to
`/var/root/Library/Caches/vphone-environment/<name>`, `environment.install
{"libraries":[{"name","sha256"}]}`, kill the app. A brand-new name reaches the
guest only through the online sync at VM start, so the first deploy needs the
bundle rebuilt + the VM restarted; after that the fast loop applies
(`[[guest-hook-iteration]]`).

Doc note: `Research/vphoned_http_api.md`'s "only four names" for
`environment.install` is **stale** — the real set is the libraries enumerated in
`VPhoneGuestEnvironment.swift` (7 today: launchdhook, SystemHook, vcamcaptured,
camfix, misfix, hapticsfix, batteryhealthfix).

## Status & handoff (2026-10-06)

### The rows the user wants hidden — all SwiftUI, all need the binary patch

Exact `SettingsSidebarListItemIdentifier` strings (from `Preferences.bin`):

| Row | identifier |
| --- | --- |
| Apple Account banner | `com.apple.settings.primaryAppleAccount` |
| Game Center | `com.apple.settings.gameCenter` |
| iCloud | `com.apple.settings.iCloud` |
| Wallet & Apple Pay | `com.apple.settings.walletAndApplePay` (also `com.apple.settings.paymentAndContactless`) |
| Software Update (under General) | `com.apple.Settings.PrimarySettingsList.SoftwareUpdateClient` |
| "Optimising Search and Siri" | `IndexingProgressListItemProvider` (no `com.apple.settings.*` id) |

None is hookable via ObjC (all pure-Swift `SettingsApp` providers). All need the
Preferences guest-executable binary patch → **blocked on a Swift decompiler**
(this build machine has only r2 + ipsw/Capstone, no Ghidra/Hopper/IDA).

### The patch, once a decompiler is available

Find the SwiftUI sidebar **item-array builder** (the function that assembles the
ordered `[SettingsSidebarListItemIdentifier]` / items for the root list and for
General), and drop the entries above — or force their per-row "should include"
to false. The identifiers are enum cases (integer tags), so a Swift decompiler is
needed to locate the append/condition; raw disassembly of the rawValue switch,
the nav `==` chain, the view bodies and the status logic (all mapped above) does
**not** reach the inclusion decision. Then ship as a guest-executable patch of
`/Applications/Preferences.app/Preferences` (same flow as the Setup.app pane
patch in `setup_assistant_pane_gating.md`): resolve via ObjC/Swift metadata,
Capstone shape-verify, `ARM64Encoder`/keystone-checked words, `.bak`, ad-hoc
re-sign. RE artifacts left on disk (until reboot): `/private/tmp/setupres/Preferences.bin`,
`…/prefs_text.asm` (full `__TEXT.__text` disass with string markup),
`…/prefs_full.txt` (ObjC class dump).

### The FollowUp-group hook (`libprefsfix`) — built, shipped once, then reverted

Covers only the CoreFollowUp suggestion groups (empty on this guest), **not** any
row above. It was fully wired and a bundle built, but its load could not be
cleanly verified live (invisible effect + pid-reuse defeating log tracing), and
it does not serve the row-hiding goal. **Uncommitted WIP in the working tree**
(keep or revert — decision pending):

- new `VPhoneGuestComponents/PrefsFix/libprefsfix.m`
- `VPhoneGuestComponents/Makefile` (PREFSFIX target)
- `VPhoneGuestComponents/SystemHook/SystemHook-vphone.c` (`vpIsPreferences` + dlopen)
- `VPhoneExecutable/VPhoneVirtualization/Build/StageBundle.sh`, `ValidateBundle.sh`
- `VPhoneKit/VPhoneCoreKit/VirtualMachine/VPhoneGuestEnvironment.swift`,
  `VPhoneDaemon/Daemon/GuestAPI+Environment.swift` (both lib lists)

The experimental bundle `2.6.0-local.0af83bc1` is still in the Launchpad store
(non-default, unbound).

### panetest state (clean)

Rebound to its original bundle `2.6.0-local.92448989`, original `SystemHook`
restored, rebooted. Durable earlier results intact and verified: the 8 removed
system apps stay gone (app count 250), OTA checker/scheduler
(`softwareupdated`/`OTATaskingAgent`) not running, the "Finish Setting Up"
row/badge cleared, `appleidsetupd` disabled. Residue: an **inert** orphan
`/usr/lib/libprefsfix.dylib` (nothing loads it now that the original SystemHook
is back; `/usr/lib` is read-only, so removing it needs a remount or a full
`cfw install`). Note: `softwareupdateservicesd` can still spin up **on-demand**
(disable blocks auto-start, not every XPC launch); the automatic OTA path is
blocked but a fully airtight block would also neutralise the catalog endpoints
(deferred — `/etc/hosts` is on the read-only root volume; see
`ota_software_update_block.md`).

## Correction: 2026-10-07 deployment review

The Codex fixed-offset patch candidates are withdrawn and must not be deployed.
`0x1000528c8` belongs to Wallet's `0x1000525c4` builder, not iCloud.
iCloud's optional-result branch is `0x10005201c` inside `0x100051df8`.
`0x100052d58` is inside the async continuation `0x100052c48`, following TaskPriority metadata setup; it is not a row-inclusion gate.
The four-site command, manifest declaration and installer call were removed pending a structural patcher and runtime validation.
The earlier SoftwareUpdateClient identifier is a Dispatch queue label for badge monitoring, not proof of a Software Update row provider. Indexing builder entry is `0x1000ee378`, not the interior address `0x1000ee8cc`.
No candidate is established as safe by byte matching or build success. Existing built bundles may still contain the withdrawn command; do not run them against a guest.

## 2026-10-07 live verification: four root rows

Scope is five rows; Indexing/Search & Siri is explicitly excluded. The previous six-row plan is superseded.

Corrected candidate now deployed on panetest-iphone, original admitted bundle 2.6.0-local.92448989, iOS 27.0 build 24A435. It hides Apple Account, Game Center, iCloud and Wallet & Apple Pay. Software Update requires a separate GeneralSettingsUI shared-cache patch and is not completed.

Original Preferences SHA256: e59851f14f29409590a6de76ca2fe9b9912341aee526a278692ef0d7a86ee2f3. Deployed signed SHA256: dc92f2f36d1f5fbb3e8f84f52487e000fe353accf99181561b4df590031a75b5. The admitted bundle signer used --merge --identifier com.apple.Preferences --apple-adhoc; codesign verifies the result and all 767 entitlement keys and values equal the original. Candidate upload used the existing VM Files browser, followed by byte-for-byte guest readback; no bundle acceptance override or host API listener was used.

The provider discovery script in /private/tmp/prefs-audit/ExperimentalProviderPatch.swift resolves resilient Swift witness records and identifies the optional nil/cleanup branch structurally. GameCenterRulePatch.swift resolves the MCFeatureGameCenterAllowed import and replaces only the Game Center sharedPad rule with boolean(false,false). These are research scripts, not yet integrated production patchers. Indexing bytes are unchanged.

Live verification completed:
- Four rows disappeared after replacement and Settings launched successfully (PID 622).
- Restoring the original executable restored all four rows (PID 629).
- Reapplying and performing a full reboot preserved the changes; new boot session 7EB4B772-FE5E-4658-A2C1-371EB76BFB84, Settings PID 381, foreground verified.
- Surrounding Settings rows remained visible.

Evidence directory: /private/tmp/prefs-audit; deployed-root-*.json, rollback-root-*.json, reboot-root-*.json and post-reboot-device.json. Guest backups: /Applications/Preferences.app/Preferences.rows-original-20261007 and Preferences.rows-previous-20261007. Current executable is the tested candidate. Production integration, Software Update deployment, and the complete five-row acceptance remain outstanding.

## Installer integration (source, 2026-10-07)

The four-row transformation is now `CustomFirmwareSettingsRows.patchPreferences`, with native Swift-witness and Mach-O indirect-symbol discovery. It is registered as `system-preferences-exp-root_rows` in Guest System, disabled by the standard preset and available in experimental. `cfw patch-settings-root-rows` patches a staged pristine Preferences binary; the shared installer calls it through `machO`, preserving original entitlements, signing Apple-ad-hoc, maintaining `.bak`, and restoring that backup when deselected. The input SHA gate still restricts application to the reviewed 24A435 original.

This source integration has not been deployed as a new bundle. The existing panetest live four-row result came from the explicitly recorded manual candidate. Software Update remains a distinct cache patch and is not covered by this declaration. Indexing remains excluded. Full build and catalogue tests are recorded separately when complete.

### Source integration verification

Independent Release VPhoneCommand build succeeded under /private/tmp/prefs-audit/integration-build. The built `cfw patch-settings-root-rows --dry-run` preserved the pristine input; real command output exactly matched Preferences.four-target-review. Test scheme was run with ENABLE_TESTABILITY=YES because Release's ordinary product module does not support @testable imports. Both Settings root rows and Bundled patch set catalogue suites passed: 19 tests, including reviewedFixtureAndUndo (not skipped), input rejection, standard opt-out, shipped preset equality, and applicable experimental selections on 18.6.2/26.4/27.0/27.1. Logs: integration-build.log, integration-tests-final.log in /private/tmp/prefs-audit.

Software Update cache candidate is staged and offline rollback verified, but guest cache replacement remains unperformed. Root was verified read-only. Automatic approval rejected the temporary writable-mount launchd request; user approval is pending. Do not treat automatic goal continuation as authorization, and do not use an indirect path around that rejection.

## 2026-10-07 authorization and five-row live closeout

User explicitly authorized the temporary writable mount. Software Update cache candidate was deployed, full-reboot verified absent, restored and full-reboot verified present, then redeployed and full-reboot verified absent again. Final UI also confirms the four root rows remain hidden. Final boot 0980B399-163F-4EBA-B8D0-51A115AD4D80, Settings PID 377. Root is read-only; temporary mount service, plist and log absent. Original cache backup remains as .settings-rows-cache36-original-20261007 beside the active chunk. See [formal report](2026-10-07_reverse-settings-rows-report.md). The earlier permission blocker is resolved. Remaining work is Software Update source installer/catalogue integration; its live test loop is complete.
