# Blocking OTA software updates on a guest

How to stop a vphone guest from ever checking for, downloading, or installing
an iOS OTA update — the update that would try to replace the research firmware.
Measured live on 2026-10-06 on `panetest-iphone` (iPhone17,3 iOS 27.0 (24A435),
cloudOS 26.4, bundle 2.6.0-local.92448989), driven over vphoned
(`vphone-launchpad-cli guest rpc <name> …`).

## TL;DR

Disable the three software-update launch daemons with `services.disable`
(persists in the data-volume launchd override DB) and reboot. After the reboot
none of them load, and Settings › General › Software Update shows **"Unable to
Check for Update."** No binary patch, no system-volume write.

| Daemon | role | action |
| --- | --- | --- |
| `com.apple.mobile.softwareupdated` | OTA check / download engine | disable |
| `com.apple.softwareupdateservicesd` | the scan the Settings pane drives | disable |
| `com.apple.OTATaskingAgent` | schedules background OTA tasks | disable |

Leave `com.apple.mobileassetd` **enabled** — it serves many non-OTA assets
(dictionaries, keyboards, Siri, fonts); disabling it breaks unrelated features.
Leave `akd` alone.

## The daemons and why these three

`services.list` on the guest, filtered to update machinery, shows the OTA set
running on a fresh boot:

```
pid 61  com.apple.mobile.softwareupdated
pid 439 com.apple.softwareupdateservicesd
pid 397 com.apple.OTATaskingAgent
pid 92  com.apple.OTACrashCopier                       # copies crash logs post-OTA; harmless
pid 373 com.apple.MobileSoftwareUpdate.CleanupPreparePathService
pid 118 com.apple.mobileassetd                         # NOT OTA-only — leave enabled
```

- `softwareupdated` is the engine that checks for and downloads the OTA, and
  posts the "update available" badge.
- `softwareupdateservicesd` is what the Settings pane and MDM drive to scan.
- `OTATaskingAgent` schedules the background automatic-update work.

Disabling those three removes both the automatic path and the manual scan. The
Settings pane launches `softwareupdateservicesd` on demand; with it disabled
launchd will not start it, so the pane errors instead of scanning — the desired
"blocked" surface.

## The recipe (measured)

```sh
G=panetest-iphone
for L in com.apple.mobile.softwareupdated \
         com.apple.softwareupdateservicesd \
         com.apple.OTATaskingAgent; do
  vphone-launchpad-cli guest rpc $G services.disable "{\"label\":\"$L\",\"force\":true}"
done
vphone-launchpad-cli vm stop  $G
vphone-launchpad-cli vm start $G --wait
```

`services.disable` → `launchctl disable`, which writes the override to
`/var/db/com.apple.xpc.launchd/` on the **data volume** — writable and durable,
no system-volume (sealed) write needed. `services.disabled` reads the three back
as `true`.

**`services.stop` does not work here** and is not needed: it returns
`launchd status 144` ("stop requires launchctl service-configure privilege"),
and so do `unload` / `remove` / `start`. The running daemons therefore keep
running (and KeepAlive-respawn after a `processes.kill`) for the rest of the
current boot; the reboot is the clean stop. `disable` itself does **not** hit
the 144 wall.

### What was measured

| Check | Result |
| --- | --- |
| `services.disabled` after disabling the three | all three `true` |
| same boot, `processes.list` | still running (KeepAlive; `stop`/`unload` blocked by priv 144) |
| after a full reboot, `processes.list {softwareupdate}` / `{OTATasking}` | **empty** — none load |
| after a full reboot, `services.disabled` | all three still `true` (override DB persisted) |
| Settings › General › Software Update (post-reboot) | **"Unable to Check for Update — An error occurred while checking for a software update."** |
| after a `vm stop` / `vm start` cycle | unchanged — daemons stay down |

"Automatic Updates" in that pane may still read **On** — it is a stored
preference, inert once the daemons that would act on it are gone.

## Endpoint blackhole (optional hardening — not required, and not trivial here)

With the daemons disabled, nothing contacts Apple's update catalog, so a DNS
block is belt-and-suspenders only. Two obvious routes are both closed on this
guest:

- **`/etc/hosts`**: `files.write` fails with `errno 30 Read-only file system`.
  `/etc` → `/private/etc` lives on the **sealed root volume**; writing it needs
  the `mount -u -w /` remount path (`environment.install` uses it) and may not
  persist. Not done.
- **`network.static_names`** (LocalOnly A records via mDNSResponder): usable,
  but `vphone-vm` calls `network.static_names.set` with the Mac's `.local` name
  **after every connect**, which replaces the table — so a gdmf/mesu entry put
  there does not survive the next connect. Not durable.

If a catalog block is ever wanted anyway, the hosts the OTA scan uses are
`gdmf.apple.com` (the modern Pallas catalog) and `mesu.apple.com` (legacy), plus
the download CDNs `appldnld.apple.com` / `updates-http.cdn-apple.com` /
`updates.cdn-apple.com`. **Do not** blackhole `gs.apple.com` — that is the
TSS / activation signing server. Given the daemon disable fully blocks OTA, the
endpoint block is left undone.

## Revert

```sh
for L in com.apple.mobile.softwareupdated \
         com.apple.softwareupdateservicesd \
         com.apple.OTATaskingAgent; do
  vphone-launchpad-cli guest rpc $G services.enable "{\"label\":\"$L\"}"
done
# reboot to let them load again
```

## Productizing

The disable is three idempotent `services.disable` calls that survive reboot —
a natural `vphone-cli`/vphoned convenience verb (e.g. `cfw block-ota` or a
vphoned `system.block_ota`) could apply and revert them in one call, and a
machine `config.plist` flag could reassert them at boot the way
`unlocksAtStartup` drives `screen.unlock`. Not built yet.

## Reproducing the pane screenshot

```sh
vphone-launchpad-cli guest unlock $G
vphone-launchpad-cli guest rpc $G apps.launch '{"bundle_id":"com.apple.Preferences"}'
# General › Software Update (the App-Prefs:root=General&path=SOFTWARE_UPDATE_LINK
# URL lands on the iOS 27 "Apps" pane instead; navigate General › Software Update
# by UI). With the daemons disabled the pane shows "Unable to Check for Update".
```
