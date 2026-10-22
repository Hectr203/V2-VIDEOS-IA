# Skipping Setup Assistant on an activated guest

Device › Skip Setup Assistant… and vphoned's `setup.status` / `setup.skip`
(`VPhoneDaemon/Daemon/GuestAPI+SetupAssistant.swift`) rest on the experiments
below, run on 2026-09-30 against `test-26.4` (iOS 26.4, already activated)
over `vphone.sock` with `settings.get/set/delete`, `system.respring`,
`processes.list` and screenshots.

## Where the state lives

Setup.app keeps its state in the `com.apple.purplebuddy` domain for user
mobile (`/var/mobile/Library/Preferences/com.apple.purplebuddy.plist`). The
key names are SetupAssistant.framework exports that Setup.app imports:

| Export | Key |
| --- | --- |
| `BYBuddyDoneKey` | `SetupDone` |
| `BYBuddyFinishedInitialRunKey` | `SetupFinishedAllSteps` |
| `BYBuddyIOSVersionKey` | `SetupVersion` |
| `BYBuddyLastExitKey` | `SetupLastExit` |
| `BYBuddyIOSCurrentVersion` | the current `SetupVersion`, an `int32` (Setup.app loads it with `ldr w2`); 11 on 26.4 and 27.0 |

A finished guest also carries `*Presented` pane flags, `*MiniBuddy*Ran`
flags, `Language`, `chronicle` and Setup's own `lastPrepareLaunchSentinel`.
No `/var/Managed Preferences/mobile/com.apple.purplebuddy.plist` override
exists on these guests.

## What each key does

Each row changes one thing from a finished guest, then restarts SpringBoard
(`system.respring`) and unlocks.

| Change | Result |
| --- | --- |
| delete `SetupDone` | full Setup (“hello”) before the Lock Screen |
| delete `SetupFinishedAllSteps` | Home Screen; Setup does not run |
| delete `SetupVersion` | the flow after a software update, after unlocking (“外观” pane, or straight to “软件更新已完成” when every `*Presented` flag is set) |
| `SetupVersion = 11` again | Home Screen |
| delete every key in the domain | full Setup; Setup writes only `lastPrepareLaunchSentinel` on launch |
| from that empty domain, set only `SetupDone`, `SetupFinishedAllSteps`, `SetupVersion = 11` | Home Screen after the restart, again after a second restart and a 25 s wait; no later panes |

## When SpringBoard decides

SpringBoard decides whether to run Setup once, when it starts.

- Setting `SetupDone = true` while Setup is on screen does not dismiss it.
  Setup switches to its “software update finished” pane, and the idle timer
  now applies, so the screen locks.
- Killing Setup then only makes SpringBoard launch it again (“hello”, swipe up
  to open).
- Restarting SpringBoard with the keys in place goes to the Lock Screen and
  then the Home Screen.

So a skip is: write the three keys through cfprefsd, then restart
SpringBoard. The write has to go through cfprefsd (`CFPreferencesSetValue`
for user mobile, then synchronize). Editing the plist file directly leaves
cfprefsd holding the old values.

## The first boot after a restore

Measured on `ss-raw` (iPhone17,3 27.0 24A435, cloudOS 26.4, never booted,
standard trim) on 2026-10-09, reverting a snapshot between runs.

On the first boot DataMigrator runs its migration plugins, starting with the
boot: `SystemAppMigrator` expands the removable system apps (the
`staged_system_apps` count falls to 0, 18 s), and the last one,
`SpringBoard.migrator` ("concurrent after WiFiDataMigrator"), ran 27 s on a
quiet guest and 67 s on one busy with log streaming. When it ends,
SpringBoard logs `[FBServiceFacilityServer] Milestone reached:
FBSServiceMilestoneDataMigrationCompleted` and only then carries on starting
up (`MobileActivation says the device is: [Activated]` and so on). At the same
moment DataMigrator records the build in `com.apple.migration` for user mobile:
`LastSystemVersion = 24A435` and `DMLastMigrationResults = {buildVersion:
24A435, success: 1}`. Before that the domain is empty. The milestone came
62–183 s after the VM started.

Until the milestone:

- Setup.app is not running (`setup.status` `running: false` throughout), so
  SpringBoard has not decided yet.
- FrontBoard ignores `SBSRelaunchAction` from `FBSSystemService` (icli's
  `respring()`): SpringBoard keeps its pid. icli's fallback, `launchctl stop
  com.apple.SpringBoard`, fails on the guest with launchd status 144
  ("Requestor lacks required entitlement"), as `services.stop/unload` do. So
  a `setup.skip` that restarts SpringBoard failed with "relaunch action
  ignored and launchd stop failed: 144 Requestor lacks required entitlement"
  until migration ended (5–11 attempts, 45–98 s, in template setup boots).
  The 144 is the fallback's error; no entitlement on vphoned changes when
  FrontBoard takes the relaunch.
- Writing the three keys is enough. With the keys written right after vphoned
  first answered and SpringBoard left alone, Setup never started after the
  milestone and the guest went to the Lock Screen.

iOS 26.6.2 (23G90, `i26-raw`, 2026-10-09) behaves the same: DataMigrator runs
from the start of the boot and records `LastSystemVersion = 23G90` 64–87 s
after the VM starts, and had not after 129 s while a 2.9.0 `setup.skip`
retried every 9 s, so a 2.9.0 setup boot ran out of its 120 s. There a second fault followed: the
2.9.0 attitude hook deadlocked SpringBoard as soon as migration ended
(`Research/Guest/virtual_attitude.md`, "Lock order"), so a relaunch was never
taken at all and Setup.app died to its launch watchdog. With the hook fixed
the setup boot passes without restarting SpringBoard.

So `setup.skip` writes the keys and leaves SpringBoard alone while data
migration is running for the running build: `kern.osversion` is not recorded
as `LastSystemVersion` or as `DMLastMigrationResults.buildVersion`, and
DataMigrator's XPC service (`…/com.apple.datamigrator.xpc/com.apple.datamigrator`,
process name `com.apple.datami`) runs. It holds its transactions for the
whole migration, from the start of the boot on. It then answers with
`respring: {restarted: false, reason: "data_migration_pending"}`. With
neither the record nor DataMigrator, it restarts SpringBoard as before, so a
guest that records elsewhere is never left waiting. When the restart fails anyway, the refusal says
the keys are written and carries `retryable: true`. `setup.settle` waits for
the same record, so a template is not frozen before migration ends (a clone
would migrate again).

## Detection

`setup_pending` in `/v1/health` is `SetupDone != true || SetupVersion <
BYBuddyIOSCurrentVersion`: two cfprefsd reads per probe. `setup.status` also
reports whether `/Applications/Setup.app/Setup` is running.
`apps.foreground` is not a usable signal. On `test-27.0` it reported
SpringBoard with `source: unavailable` while an app was in front.

## Not covered

- Mini flows triggered by other keys (`*MiniBuddy*Ran`, missing `*Presented`
  flags on a later build) are not detected or skipped. None appeared with
  only the three keys set.
- The skip does not check activation. On an unactivated guest SpringBoard
  still needs activation.
- MCInstall `SetCloudConfiguration` with `SkipSetup` keys, which
  pymobiledevice3 `profile supervise`, go-ios `prepare` and `cfgutil prepare`
  use, applies only to an erased device. The device refuses a second
  configuration (error 14002), so it does not fit a guest that is already
  set up or activated.

## Returning a guest to Setup Assistant

To see Setup again for testing, delete `SetupDone` with `settings.delete` and
restart SpringBoard. Delete `SetupVersion` instead to see the flow after a
software update. Save the domain first with `settings.get`, because deleting
every key loses the pane flags and `Language`.
