# Post-setup sign-in surfaces and removing the App Store

Companion to `setup_assistant_pane_gating.md`: what the Apple ID / iCloud
sign-in surfaces look like *after* Setup finishes on a guest that never signed
in, what it takes to suppress them, and how the App Store — a staged system
app — is actually removed. Measured 2026-10-06 on `ipad-mini-01` (iPadOS
26.6.2, setup completed, never signed in, bundle 2.6.0-local.92448989) plus
static analysis of the iPhone17,3 27.0 (24A435) images; `panetest-iphone`
(ios 27.0 + cloudOS 26.4) is the fresh-machine testbed for the open items.

## TL;DR

- A finished, never-signed-in guest shows **one** sign-in surface today: the
  "Apple Account / Sign in to access iCloud data, the App Store…" card at the top of
  Settings. No Settings badge, no sign-in notification — the follow-up
  machinery is running (`followupd`, `appleidsetupd`, `akd`) but has posted
  nothing visible.
- Suppression ladder: (1) do nothing and re-check after the Setup pane patch
  lands; (2) disable `followupd` + `appleidsetupd` (two plist writes, kills
  the naggers at the source); (3) DSC-patch `FLFollowUpController
  postFollowUpItem*` to return NO (kills every follow-up system-wide). The
  Settings card itself only disappears by patching Settings.app — an inert
  row; recommended against.
- Removable system apps **can** be deleted durably. Their running copies live
  on the data volume (`/private/var/containers/Bundle/Application/<uuid>/`).
  `apps.uninstall`'s `LSApplicationWorkspace` fallback refuses them, so the
  removal is: `apps.unregister` the bundle (LS) → `files.remove` the **whole
  container** (not just the `.app`) → `system.respring`. Removing only the
  `.app` is **not durable** — iOS re-materializes the app from the container's
  `SerializedPlaceholder.ipa` on the next boot (this is why the App Store the
  prior pass "removed" was back after a reboot). Measured end-to-end on
  `panetest-iphone` (2026-10-06): News removed, survived a full reboot while a
  file-only-removed App Store came back; then Home, TV, News, FaceTime, iTunes
  Store, Messages, Camera and App Store all removed and survived a `vm stop` /
  `vm start` cycle (app count 258 → 250).

## What "sign-in" surfaces exist after Setup

Measured on `ipad-mini-01` (screenshot 2026-10-06 00:24, Settings root) and,
after a full fresh Setup walk, on `panetest-iphone` (iOS 27.0, 2026-10-06 —
the Apple ID pane was skipped by hand via *Set Up Later*, then `setup.skip`
ended the control run):

| Surface | ipad-mini-01 (setup long done) | panetest-iphone (fresh setup) | Driven by |
| --- | --- | --- | --- |
| Settings root card "Apple Account / Sign in to access iCloud data, the App Store, Apple services…" | yes | yes ("Apple Account — Log in voor toegang tot onder andere je iCloud…") | Settings' own root list (Swift `SettingsApp` module; groups built in `FLTopLevelViewModel sapp_groupsWithQueue:completion:`, Preferences binary) from account state |
| Settings icon badge | none | **yes — red "1"** | pending CoreFollowUp items |
| "Finish Setting Up Your iPhone" row in Settings | none | **yes** | a follow-up item created by the Apple ID skip / setup completing without an account |
| "Sign in to iCloud" notifications | none today | not seen in the short window | follow-up items → notifications |
| Post-setup passcode nag | none (nothing to nag; the pane just fails — `system_keybag_passcode.md`) | none | — |

So the fresh, never-signed-in guest *does* acquire a follow-up (badge +
"Finish Setting Up" row) even though nothing nags on the older guest. The
ladder below covers both.

Daemons running on that guest: `followupd` (203), `appleidsetupd` (180),
`akd` (177), `appstored` (183), `itunesstored` (207), `storekitd` (184).

## The follow-up machinery (static, 27.0)

`CoreFollowUp.framework` in the shared cache carries `FLFollowUpController`,
the client every poster uses. Method IMPs (unslid, 27.0 cache):

| Method | Address |
| --- | --- |
| `-[FLFollowUpController postFollowUpItem:error:]` | `0x2027db700` |
| `-[FLFollowUpController postFollowUpItem:completion:]` | `0x2027dc744` |
| `-[FLFollowUpController updateBadgesForTimer]` | `0x2027dd364` |
| `-[FLFollowUpController clearPendingFollowUpItems...]` / `pendingFollowUpItems...` | see dump |

plus the HSA2 (iCloud Keychain sign-in) notification family
(`_postHSA2LoginNotification:`, `_postHSA2PasswordChangeForAppleID:` …).
`com.apple.followupd.plist` is the server; `com.apple.appleidsetupd.plist`
drives the "finish setting up your Apple ID" flows (`AppleIDSetupDaemon`,
`AppleIDSetupUIService.app`, `ProximityAppleIDSetup`).

### Suppression ladder

1. **Do nothing (measure first).** Depends on how the guest got here: a
   fresh setup with a hand-skipped Apple ID pane leaves the badge and the
   "Finish Setting Up" row (`panetest-iphone`); the older finished guest
   shows neither. The pane patch in `setup_assistant_pane_gating.md` skips
   the pane at `controllerNeedsToRun` — nobody presses "Set Up Later" — and
   may therefore leave no follow-up at all. Verify after that patch lands.
2. **Disable `appleidsetupd`, clear the item store, keep `followupd`** — the
   measured recipe (see below). Do it with `services.disable` (persists in the
   data-volume launchd override DB, `/var/db/com.apple.xpc.launchd/`), not by
   editing the sealed-volume plists. Disabling `appleidsetupd` stops the Apple
   ID follow-up from being re-posted; removing
   `/var/mobile/Library/CoreFollowUp/items.db` (+ `-wal`/`-shm`) drops the
   pending item; **leaving `followupd` enabled** lets it reconcile the Settings
   icon badge to 0 on the next boot. Disabling `followupd` **as well** is the
   trap: it removes the Settings *row* but orphans the icon *badge* (the badge
   was already pushed to SpringBoard and survives a respring with nothing left
   to zero it).
3. **DSC patch.** `postFollowUpItem:error:` and
   `postFollowUpItem:completion:` → return NO (same leaf-rewrite shape as the
   pane patch). Suppresses every follow-up item system-wide — including
   software-update and storage badges; on a research guest that is usually
   acceptable, but it is broader than the ask.
4. **The Settings card** would need a Settings.app patch (Swift UI, brittle,
   and the row is inert). Recommended against; not part of this work.

### Measured (panetest-iphone, 2026-10-06)

The fresh guest showed the red **"1"** on the Settings icon and a **"Finish
Setting Up Your iPhone"** row at Settings root — confirmed to be the CoreFollowUp
item created by the hand-skipped Apple ID during setup, stored in
`/var/mobile/Library/CoreFollowUp/items.db` (SQLite).

```sh
G=panetest-iphone
vphone-launchpad-cli guest rpc $G services.disable '{"label":"com.apple.appleidsetupd","force":true}'
for f in items.db items.db-wal items.db-shm; do
  vphone-launchpad-cli guest rpc $G files.remove "{\"path\":\"/var/mobile/Library/CoreFollowUp/$f\"}"
done
vphone-launchpad-cli guest rpc $G system.respring '{"force":true}'   # row goes now
vphone-launchpad-cli vm stop $G && vphone-launchpad-cli vm start $G --wait   # badge goes on boot
```

| Check | Result |
| --- | --- |
| after `files.remove items.db` + respring | "Finish Setting Up" **row gone** from Settings root; Settings icon **badge still "1"** (orphaned) |
| disabling `followupd` too (first attempt) | did **not** clear the badge — confirms the orphan; re-enabled it |
| after a full reboot (followupd enabled, store empty, `appleidsetupd` disabled) | Settings icon **badge gone**; row stays gone; `items.db` recreated but empty; `apps` all still removed; OTA still blocked |

So the respring clears the row but only a boot (followupd's boot-time badge
reconciliation) clears the icon badge. `appleidsetupd` stays disabled so the
Apple ID follow-up is not re-posted; `followupd` stays enabled so it can zero the
badge. The **"Apple Account — Sign in…" card itself remains** (ladder step 4,
left intact by recommendation).

## Removing removable system apps (durably)

Measured live on `panetest-iphone` (iPhone17,3 iOS 27.0, 2026-10-06). These
are the user-facing removable system apps — the ones with a placeholder in
`/System/Library/AppPlaceholders` (52 of them: App Store, Home, TV, News,
FaceTime, iTunes Store (`MobileStore`), Messages (`MobileSMS`), Camera, …).
Each is installed on **first boot** into its own container on the data volume
(`/private/var/containers/Bundle/Application/<uuid>/`), which is writable and
not sealed, with `staged_system_apps` emptied afterward.

### The re-stage trap (why the earlier App Store removal came back)

The container holds more than the `.app`:

```
/private/var/containers/Bundle/Application/<uuid>/
  AppStore.app/                                 ← the bundle
  SerializedPlaceholder.ipa                     ← the re-download stub (icon art + install payload)
  BundleMetadata.plist
  .com.apple.mobile_container_manager.metadata.plist
```

Removing **only** the `.app` subdir (the earlier recipe) and resprininging
hides the icon for that session, but **LaunchServices still has the app
registered**, so on the next boot installd "repairs" the registered-but-missing
bundle by re-expanding `SerializedPlaceholder.ipa` — the icon returns (as it did
for the App Store this pass found still present after a reboot, with a stale
`apps.list` record at the old path). `/System/Library/AppPlaceholders/<App>.app`
on the sealed root volume is the master source these placeholders seed from.

### The durable recipe

Three RPCs per app (plus an optional backup):

```sh
G=panetest-iphone
APP=/private/var/containers/Bundle/Application/<uuid>/News.app   # from apps.list bundle_path
CONT=$(dirname "$APP")
# optional revert backup (container is small: metadata + ~1.3 MB placeholder + thin .app)
vphone-launchpad-cli guest rpc $G files.copy "{\"from\":\"$CONT\",\"to\":\"/private/var/mobile/Library/removed-system-apps/News.container\"}"
vphone-launchpad-cli guest rpc $G apps.unregister "{\"path\":\"$APP\",\"force\":true}"   # LS removes the registration
vphone-launchpad-cli guest rpc $G files.remove    "{\"path\":\"$CONT\",\"recursive\":true}" # whole container, incl. the placeholder
vphone-launchpad-cli guest rpc $G system.respring '{"force":true}'
```

`apps.unregister {path, force:true}` is IcliKit's path-based LS unregister (the
`icli_unregister_app` the earlier note wanted — it **is** exposed). Doing it
*before* removing the files is what stops installd from re-materializing the app:
with no registration there is nothing to repair, and with the container (and its
`SerializedPlaceholder.ipa`) gone there is nothing to repair it from.

Revert: `files.copy` the backup container back, then `apps.register` the `.app`
inside it (or `system.uicache`), then respring. A full restore also brings the
app back from the image.

### What was measured

| Check | Result |
| --- | --- |
| `apps.uninstall {"bundle_id":"com.apple.news","force":true}` | **refused** (same as App Store — `LSApplicationWorkspace` returns false for a system app) |
| durable recipe on News → respring | `apps.list` record gone, icon gone |
| **full `system.reboot`** | News **stays gone**; App Store (file-only-removed earlier, container kept) **comes back** — the clean A/B for the recipe |
| Home, TV, News, FaceTime, iTunes Store, Messages, Camera, App Store all removed by the durable recipe → respring | all 8 records gone; home reflowed to one page, no dead icons; Messages left the dock (Phone · Safari · Music remain) |
| **`vm stop` + `vm start`** | all 8 stay gone; app count 258 → 250; no container dirs recreated |

Store daemons (`appstored`, `itunesstored`, `appstorecomponentsd`) keep running
after the App Store bundle is gone; disable them too (`services.disable`, as in
`ota_software_update_block.md`) for no store traffic. Keep `storekitd` — apps
the researcher installs may link StoreKit.

### One verb: `apps.remove_system`

vphoned now folds the durable sequence into one call:
`apps.remove_system {"bundle_ids":[…],"force":true}` reads each app's current
container from the live app list, backs the whole container up to
`/private/var/db/vphoned/removed-system-apps/<bundle_id>.container` with a
manifest beside it, unregisters the app, removes the container and resprings
once. The backup directory is root-only (0700) and on the Data volume, like
the bundle containers, so the backup is an APFS clone that costs next to
nothing and the restore is a rename. The first version of the verb used
`/private/var/mobile/Library/removed-system-apps`, the hand recipe's
directory; `/private/var/mobile` is the User volume, so those backups were full
copies and their restore failed with EXDEV. Backups there are still listed
(`legacy: true`) and restored, by a copy that keeps owners, modes, extended
attributes and flags, after which the legacy copy is removed. It refuses apps outside `/private/var/containers/Bundle/Application/<UUID>/`
(Phone and the rest of `/Applications`). `apps.restore_system` moves a backup
back to its original UUID path and registers it, and `apps.removed_system`
lists the backups. icli's `apps.register` refuses Apple's apps since 0.7.17, so
the hand recipe's revert step above no longer works through it. See
`Research/vphoned_http_api.md`, "Removable system apps and APFS snapshots".

## Open items

1. Whether the pane patch (`setup_assistant_pane_gating.md`), which skips the
   Apple ID pane without anyone pressing "Set Up Later", leaves the badge /
   "Finish Setting Up" row uncreated — the freshest data point says a
   hand-skipped pane does create it, so this is the interesting check once
   the patch builds.
2. ~~Whether disabling `followupd`/`appleidsetupd` clears the badge.~~
   **Resolved** (see "Measured" above): disable `appleidsetupd` + clear
   `items.db` + keep `followupd` enabled; the badge clears on the next boot.
3. `panetest-iphone` is left **running**. Applied this pass and verified durable
   across a `vm stop`/`vm start` cycle: Home, TV, News, FaceTime, iTunes Store,
   Messages, Camera and App Store removed (backups under
   `/private/var/mobile/Library/removed-system-apps/`); OTA blocked
   (`ota_software_update_block.md`); the "Finish Setting Up" row/badge cleared.
   The only sign-in surface left is the inert Settings "Apple Account" card.
   The purplebuddy domain was restored (2026-10-06, after the pane A/B walks)
   from the completed-setup backup: all 29 keys back through `settings.set`,
   `SetupDone` kept, `Passcode4Presented` correctly absent (Setup clears it at
   buddy-done), so the passcode pane behaves stock — re-entering Setup (delete
   `SetupDone`) shows it again.

Note on creating `panetest-iphone`: the first attempt timed out — first boot
reached the vphoned boundary exactly at the create wrapper's 300 s window
(camera on vsock 1338 connected at the timeout edge; kernel console healthy,
no panic), and the wrapper tore the machine down. The retry succeeded within
the window. If 27.0 first boots on a given Mac routinely exceed it, the
`firstBoot` step's wait needs a look in Launchpad before fresh 27.0 machines
can be created there at all.

## Reproducing the static bits

Same extraction flow as `setup_assistant_pane_gating.md`. The Preferences
binary is `/Applications/Preferences.app/Preferences` (Swift-first — only 78
ObjC classes dump; the root list is `FLTopLevelViewModel
sapp_groupsWithQueue:completion:`); CoreFollowUp classes via
`ipsw class-dump <dsc> /System/Library/PrivateFrameworks/CoreFollowUp.framework/CoreFollowUp --re -V`.

## 2026-10-07: Games and Phone app entries

User requested hiding Games and Phone entry points. On panetest-iphone, unregistered `com.apple.games` and `com.apple.mobilephone`, then moved program files into `/var/root/hidden-app-entries-20261007/` rather than deleting them. Games' entire bundle container (including placeholder metadata) was moved to `Games.container`; `/Applications/MobilePhone.app` was moved to `MobilePhone.app`. `com.apple.GameTrampoline` already carries `SBAppTags=[hidden]` and was left intact, as were Game Center widgets/services.

After full reboot, both target registrations remain absent (app count 250 → 248). Screenshots confirm no Games/Phone icon on either home page or in App Library; dock contains Safari and Music. Settings launches with foreground verified. Root is read-only again. The temporary remount job was unloaded, its plist removed and its log deleted.

Original data containers were retained and directory reads succeeded after reboot:
- Games: `/private/var/mobile/Containers/Data/Application/DBA101EC-66DF-4C79-906F-14C958771D2B`
- Phone: `/private/var/mobile/Containers/Data/Application/304C2592-BF11-440F-90B9-2D84CF4FF503`

To restore on this guest, temporarily remount root writable, move `Games.container` back to `/private/var/containers/Bundle/Application/90D1ADC8-1429-4D25-96C0-E270D6A3D688` and the saved `MobilePhone.app` back to `/Applications/MobilePhone.app`, register each `.app` path, then reboot. Both backup entries were verified present after reboot. This removes app launchability together with the icon; it does not stop underlying telephony daemons.

Evidence: `/private/tmp/prefs-audit/hidden-apps-post-reboot.json`, `hidden-apps-environment.json`, `hidden-apps-device.json`, `hidden-app-backups-post-reboot.json`, `hidden-apps-home-current.jpg`, `hidden-apps-library.jpg` (second home page), and `hidden-apps-library-final.jpg` (actual App Library). SpringBoard UI-tree requests cannot verify the foreground home scene on this build, so visible icon checks use screenshots rather than treating that API failure as a successful check.

## 2026-10-07: Find My entry removed

Unregistered `com.apple.findmy`, then moved its entire bundle container from `/private/var/containers/Bundle/Application/6EB8CC54-634C-4191-9A18-8287D20C55A1` to `/var/root/hidden-app-entries-20261007/FindMy.container`. The data container `/private/var/mobile/Containers/Data/Application/A3EA4863-9650-4135-B0C6-246E7BF253F9` and Find My auxiliary services were retained. Backup and data directory reads succeeded afterwards.

The first guest-initiated reboot left vphoned disconnected and the window black. Launchpad reported running, panicked=false; serial logs continued APFS activity and no panic record was found. Preserved that log as `/private/tmp/prefs-audit/findmy-pre-recovery-console.log`. Normal `vm stop` then `vm start --wait` with the original bundle restored vphoned in 10 seconds. This recovery does not establish the root cause of the earlier disconnect.

After that complete VM restart, Find My remained absent from registrations (248 → 247); Settings launch had foreground verified, and the second home page screenshot confirmed the Find My icon gone and the UI responsive. Evidence: findmy-post-recovery-apps.json, findmy-backup-verified.json, findmy-data-verified.json, findmy-final-screen.jpg in /private/tmp/prefs-audit. Restore by moving the saved full container back to its original UUID path, registering FindMy.app, then respring/reboot. No kernel patch or host security setting changed during this removal.

## 2026-10-07: Wallet app entry removed

Removed the Wallet main app (`com.apple.Passbook`) from panetest-iphone by unregistering its bundle and moving the complete program container, including placeholder metadata, from `/private/var/containers/Bundle/Application/22E11AE9-A1A6-4533-8F4F-CBF82D1FF026` to `/var/root/hidden-app-entries-20261007/Wallet.container`. The data container `/private/var/mobile/Containers/Data/Application/BFDA90DC-29FB-4885-8CB0-39A165724970` was retained. FinanceStub and Wallet UI/credential helper services were left intact. This app removal is separate from the already implemented Wallet & Apple Pay Settings-row patch.

The first immediate VM stop/start still showed a stale Wallet registration and icon. The original container directory did not exist, and a second unregister reported that the app was not registered, so the evidence does not establish that its program files were restored. After respring, the registration disappeared. A second complete VM stop/start then confirmed persistent absence (247 → 246 registered apps), and a fresh home-screen screenshot showed Settings occupying Wallet's former position. Root remained read-only; no writable remount was required for this data-volume operation.

The backup and retained data directory were read successfully. To restore, move `Wallet.container` back to its original UUID path, register the enclosed `Passbook.app`, and respring before checking a full restart. Host evidence is under `/private/tmp/prefs-audit`: `wallet-final-apps.json`, `wallet-final-environment.json`, `wallet-final-screen.jpg`, `wallet-backup.json` and `wallet-data.json`.
