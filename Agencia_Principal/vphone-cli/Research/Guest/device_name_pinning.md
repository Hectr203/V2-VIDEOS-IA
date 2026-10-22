# Device name pinning

The host can give a guest a fixed device name, the one Xcode's DeviceHub,
`devicectl`, Finder and the guest's own Settings show, and keep it from being
renamed inside the guest or from the host. The name is the VM's name:
`vphone-vm` hands it to vphoned after every connect, vphoned stores it in the
guest, and `libdevicename.dylib` in configd and lockdownd applies it.

Static analysis of the iOS 27.0 (24A435) `configd` and `lockdownd` from an
`iPhone17,3` guest, 2026-10-07. Addresses are from those binaries. Run on an
iOS 27.0 guest; see [Verification](#verification).

## Where the name lives

The device name is `System/System/ComputerName` in
`/private/var/preferences/SystemConfiguration/preferences.plist`. Nothing reads
it from there directly. configd publishes it into the dynamic store, and every
reader goes through the store:

```text
preferences.plist ── configd PreferencesMonitor ──> Setup:/System { ComputerName, ComputerNameEncoding }
                                                        │
       SCDynamicStoreCopyComputerName ─────────────────┤
         lockdownd copy_device_name  (lockdown GetValue DeviceName: Finder, Xcode, devicectl)
         MobileGestalt UserAssignedDeviceName, UIDevice.name
```

configd's `updateConfiguration` (PreferencesMonitor, statically linked into
`/usr/libexec/configd`; `0x100062098`…) does the publishing:

1. `SCDynamicStoreCopyMultiple(store, NULL, ["^Setup:.*"])`: what the store has.
2. `SCPreferencesCopyKeyList`, then `SCPreferencesGetValue(prefs,
   kSCPrefSystem)` flattened from `/` into `Setup:/…` keys (`0x100064578`), so
   `System/System` becomes `Setup:/System`. The current set is flattened the
   same way.
3. Keys whose value did not change are dropped; keys that disappeared are
   collected for removal.
4. One `SCDynamicStoreSetMultiple(store, keysToSet, keysToRemove, NULL)`
   (`0x100062c04`).

Renames come in through lockdownd's `set_device_name` (`0x1000073b0`):
`SCPreferencesCreate("com.apple.mobile.lockdown")`, `SCPreferencesLock`,
`SCPreferencesSetComputerName(prefs, name, kCFStringEncodingUTF8)`,
`SCPreferencesSetHostName` and `SCPreferencesSetLocalHostName` with a sanitized
name, `SCPreferencesCommitChanges`, `SCPreferencesApplyChanges`. These are
lockdownd's only callers of the three setters. A failing setter is only
logged, and the function still commits. It has two callers:

- startup (`0x100011e4c`…`0x100011ec0`): every time lockdownd starts it calls
  `set_device_name(copy_device_name())`, or with `MarketingDeviceFamilyName`
  when there is no name, and records the name in its data ark (`-DeviceName`);
- the lockdown `SetValue DeviceName` handler (`0x10001ed7c`), which ignores
  the result. The host's rename (Finder, `idevicename`) arrives here.

## The channel

The name is `DeviceName` in `/var/db/vphone/devicename.plist`, a binary
property list beside `misfix.plist`, mode 0644, owned by root. vphoned writes
it, replacing the file in one rename, and removes it:

- `device.name.set {name}` stores a name (not blank, at most 255 UTF-8 bytes,
  no control character: `VPhoneGuestDeviceName` on the host) and returns
  `{name, changed}`; `{name: null}` removes the file; `device.name.get` returns
  `{name}`. Capability `device_name`.
- After a change vphoned applies configd's preferences unchanged
  (`SCPreferencesApplyChanges`) so configd publishes again, and posts
  `com.apple.mobile.lockdown.device_name_changed`.
- `vphone-vm` calls `device.name.set` with the VM's name (the folder holding
  `config.plist`) on every connect, or with null for a VM name that breaks the
  rule. There is no setting.

The file survives a reboot, so from the second boot on configd's first
publication already carries the name, before lockdownd first asks for it. The
first boot after the feature arrives, and the first boot after `vm rename`,
start with the previous name (or none) and change when vphoned connects.

The library checks the file on each decision (`stat`; read again when inode,
size or modification time changed), not once per process. The value must be
1 to 255 bytes of valid UTF-8 with no control characters; a missing file, one
that does not parse, or any other value means nothing is pinned and every call
passes through.

### NVRAM does not reach the guest

The first channel was an NVRAM variable, `vphone-device-name`, written by
`vphone-vm` through `VZMacAuxiliaryStorage`'s private
`_setDataValue:forNVRAMVariableNamed:error:` before each boot. It never
arrived (2026-10-07, dhtest-iphone27):

- `IODeviceTree:/options` in the guest had 8 properties: `StartupMute`,
  `boot-breadcrumbs`, `fm-spstatus`, `user_language_enum`,
  `fm-activation-locked`, `boot-args`, `auto-boot`, `fm-locktype`. Neither the
  bare name nor the Apple-GUID form was there, read from lockdownd as root.
- `nvram.bin` keeps iBoot's two 512 KiB "common" banks at `0xa04000` and
  `0xa84000` (header `Z\x82\x02\x00 nvram`, adler32 of bank+0x14…+0x80000 at
  +0x10). A `vphone-device-name=…` entry added to the newest bank by hand, with
  the checksum fixed, was gone from both banks after one boot.
- `vphone-vm`'s own `boot-args` write (`serial=3 debug=0x104c04`) does not
  reach the guest either: the banks hold an empty `boot-args=`, and launchd
  logs `boot-args = serial=3 -v debug=0x2014e`, the string the iBoot patch
  supplies.

iBoot rewrites the store with the variables it knows (its list of names is in
`nvram.bin`) and drops the rest, so the host cannot hand the guest anything
through NVRAM. vphoned is the channel instead.

## configd: publishing the pinned name

`SCDynamicStoreSetMultiple` is interposed. For a call that sets or removes
anything under `Setup:`, which in configd is the preferences monitor,
`Setup:/System` is rewritten so its `ComputerName` is the pinned name and its
`ComputerNameEncoding` is UTF-8. Other entries stay. Calls that publish only
`State:` keys, from configd's other plugins, never read the file.

- The call sets `Setup:/System`: its value is pinned.
- The call leaves it out because it did not change: the store's current value
  (`SCDynamicStoreCopyValue`) is pinned and added if it names anything else.
  This covers a first boot whose preferences have no name.
- The call removes it: the removal is dropped and a value holding the pinned
  name is set instead.

`SCDynamicStoreSetValue("Setup:/System", …)` is pinned the same way. No configd
caller is known to set that key directly.

A name set while the guest runs takes effect at once. vphoned's apply makes the
monitor publish even though the preferences did not change. Measured with a
tracing build (24A435): with the store holding the guest's own name, the call
sets one `Setup:` key and leaves `Setup:/System` out, and the store's value gets
the pin; with a pin in the store and none in the file any more, the call sets
`Setup:/System` to the preferences' value (the monitor compares with the store),
so the guest's own name returns without a reboot.

The pin is applied when configd publishes, not when it reads the
preferences. Replacing what `SCPreferencesGetValue(prefs, kSCPrefSystem)`
returns would reach the same flattening, but the monitor's model-change path
(`sub_10006155c`) reads that value and writes it back with
`SCPreferencesSetValue` around `__SCNetworkConfigurationSaveModel`, which
would commit the pinned name to disk. Applied at publication, it never
reaches `preferences.plist`.

Not pinned: `LocalHostName` and the DNS host name, which are separate keys
derived from the name when it is set; set-hostname's
`__SCPreferencesCopyComputerName` (`0x100049fcc`), which reads the file
directly to decide a DNS host name after a reverse lookup.

## lockdownd: refusing renames

While a name is pinned, `SCPreferencesSetComputerName` returns false and sets
`kSCStatusAccessError` (`_SCErrorSet`, exported by SystemConfiguration),
whatever the name. The host name and local host name setters that follow on
the same preferences object are refused too, so the commit changes nothing.

Because `set_device_name` and its `SetValue` handler ignore the failures, a
host that renames the guest is told it worked, and the name stays.

The pinned name itself is refused as well. lockdownd calls
`set_device_name(copy_device_name())` every time it starts. At boot that runs
before configd's first publication and asks for the name the preferences
already hold (seen as `refused SCPreferencesSetComputerName("probe-two")` while
the pin was `dhtest-iphone27`). A lockdownd started later, after a crash or
vphoned's `udid.set`/`udid.clear`, which stop it, reads the pinned name from the
store. A first version let a rename to the pinned name through, and one such
restart wrote `ComputerName "dhtest 27 测试"`, `HostName` and `LocalHostName`
`dhtest-27-ceshi` into `preferences.plist`. Refusing every rename while pinned
keeps the file as the guest left it; the refusal of the pinned name is logged
like any other.

## Injection

Both spawn hooks insert `/usr/lib/libdevicename.dylib` into
`/usr/libexec/configd` and `/usr/libexec/lockdownd` (`vpIsDeviceNameTarget` in
`Shared/InjectionEnvironment.h`). lockdownd also takes `libmisfix.dylib`, so
`vpInsertedLibrariesFor` returns every library for a path and lockdownd starts
with
`DYLD_INSERT_LIBRARIES=/usr/lib/SystemHook-vphone.dylib:/usr/lib/libmisfix.dylib:/usr/lib/libdevicename.dylib`.
A job launchd spawns itself goes through the launchd hook; one started through
`xpcproxy` goes through SystemHook. Either way it gets both libraries, and an
environment that already names some of them gains only the missing ones. On
24A435 both come through SystemHook: `vphone-systemhook-spawn.log` has
`configd decision=inserted+devicename` and `lockdownd
decision=inserted+misfix+devicename`.

The interposes reach configd's and lockdownd's calls because both are
standalone images binding through their own imports. A call made inside the
shared cache is not rebound (see "An interpose does not cross the shared
cache" in `0_binary_patch_comparison.md`). The library checks
`getprogname()` and acts only in configd or lockdownd.

The library ships with `system-launchdaemons-boot-environment` and with the
environment update. A guest that receives it from an online update starts
using it at its next boot, when configd and lockdownd are spawned again.

## What the host sees, and when

- lockdown readers (`ideviceinfo -k DeviceName`, Finder, `idevicename`) read
  the store on every request, so they follow a change at once.
- CoreDevice (`xcrun devicectl`, Xcode's device list, DeviceHub) reads the
  name when the device's remote service appears, near the time vphoned first
  answers, and keeps it. After `vm rename` the first boot is a race: one run
  showed the new name, another kept the old one until the next boot.
  Restarting the guest's remoted to force a new handshake is not an option:
  launchd only starts it again with a new NCM link, and after a USB
  re-enumeration (`udid.clear`) the host's remoted failed to connect
  (`connect(2) … Operation timed out`) and CoreDevice dropped the device until
  the guest rebooted.

## Assumptions not yet checked

- PreferencesMonitor is the only publisher of `Setup:/System`.
- Settings' General → About → Name goes through lockdownd (seen statically).
  If Settings writes the preferences itself, it is not refused, but configd
  still publishes the pinned name.
- iOS 26.x guests: not run yet.

## Verification

Run 2026-10-07 on dhtest-iphone27 (iPhone99,11, iOS 27.0 24A435), VM name
`dhtest-iphone27`, then renamed to `dhtest 27 测试`. Logs:
`/var/mobile/Library/Caches/vphone-devicename.log` in the guest, `[device]`
lines in the VM's console log on the host.

1. First boot without the file: `vm start --wait` returned 5 s after start,
   and the first `ideviceinfo -k DeviceName` answer a second later was already
   `dhtest-iphone27`; configd logged `pinned name "dhtest-iphone27"` and
   `published Setup:/System ComputerName "dhtest-iphone27"` after vphoned
   connected.
2. Reboot with the file: configd's first publication carries the pin, before
   lockdownd's start-up rename (refused), and the first lockdown answer and
   `devicectl` show `dhtest-iphone27`.
3. `idevicename "Renamed By Host"` prints success; `ideviceinfo` and
   `devicectl` keep `dhtest-iphone27`; `preferences.plist` keeps
   `ComputerName`/`HostName`/`LocalHostName` `probe-two`; the log has the three
   refusals.
4. `vm rename` to `dhtest 27 测试`, boot: the first lockdown answer (1 s after
   vphoned answered) was `dhtest 27 测试`; configd logged the old pin at boot,
   then the new one. `devicectl` showed the new name in this run.
5. `device.name.set null` while running: `ideviceinfo` showed the guest's own
   name 1 s later; setting the name again pinned it 1 s later. lockdownd
   killed while pinned came back, refused its start-up rename to the pinned
   name, and `preferences.plist` kept its name.

Host-side checks need no guest: `make -C VPhoneGuestComponents
test-injection-environment test-devicename` covers target matching,
lockdownd's two libraries, reading the file's contents, the publication
rewrite and the rename decision; `VPhoneCoreKitTests` covers the host's name
rule.
