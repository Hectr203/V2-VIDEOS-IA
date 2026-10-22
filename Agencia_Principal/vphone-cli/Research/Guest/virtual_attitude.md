# Device attitude simulation

## Contract and panel

vphoned capability `motion_attitude` exposes `motion.attitude.get`,
`motion.attitude.set {roll,pitch,yaw,enabled?}` and `motion.attitude.clear`.
Set requires finite JSON numbers: roll/yaw in [-180,180] degrees, pitch in
[-90,90]. Booleans, strings, missing/non-finite/out-of-range angles are rejected.
`enabled` must be a Boolean and defaults to true. Clear disables and zeros;
set with enabled=false retains angles.

**Features → Motion Sensors → Device Attitude** (Chinese:
**功能 → 运动传感器 → 设备姿态**) offers immediate edits, a simulation checkbox
and zero reset preserving the checkbox. The gyro panel is in the same submenu.
Both share the serialized/coalesced writer and retry/reconnect model.
UI/RPC use degrees; Core Motion uses radians. Zero is face-up, gravity (0,0,-1)
g. Pitch is about X, roll about Y, yaw about Z: R = Rz(yaw) Rx(pitch) Ry(roll).
Pitch ±90° makes Euler roll/yaw singular; quaternion/matrix remain well-defined.

This is a stationary pose, independent of raw gyro simulation. Device motion
supplies attitude, corresponding gravity, zero rotation rate/user acceleration,
an uncalibrated zero magnetic field and invalid heading (-1). Changing angles
does not synthesize angular velocity or UIKit/display orientation changes.

## Injection and transport

Guest System declares `system-apps-cfw-attitude`, selected by both presets on
iOS 18+. It adds `/usr/lib/libvphoneattitude.dylib`. SystemHook loads it into
apps before the optional tweak loader; no bootstrap or new daemon is required.
The attitude loader excludes `/System/Library/` processes and SpringBoard
copies, even though their executable paths can contain `.app/`. The dylib
enforces the same exclusion before registering notifications or replacing
methods, so an older SystemHook cannot activate the hook in those services
after a live library update.
Safe-mode/injection-disable flags still apply. No system executable, kernel or
DSC bytes change. This intercepts the app's public Core Motion boundary;
it does not claim that raw gyro HID events are fused attitude samples.

All four CMMotionManager device-motion start methods, stop, interval, polling,
availability, active state and reference-frame getters are covered. Only
XArbitraryZVertical is simulated/advertised. Corrected/magnetic/true-north
requests keep the native path. Enable simulation before launching an app whose
availability check would otherwise prevent subscription.

Per-manager timers honor intervals at 1–200 Hz (unset: 60 Hz). Callbacks run on
the app's NSOperationQueue, outside session locks. At most one simulated
delivery is queued; a suspended queue cannot accumulate samples. Generations
discard deliveries after stop/restart/mode changes. Samples support independent
copies, secure coding and relative quaternion multiplication. Weak timer
captures and cancellation prevent a timer retaining a released manager.
Enabling/disabling an existing subscription switches between simulation and
retained native implementations, including native availability when disabled.
Native stop is forwarded only for a subscription previously forwarded to
native start. A new or purely simulated subscription never initializes native
Core Motion by stopping it; repeated stops remain local after native shutdown.

### Lock order

The original app gate matched every path containing `.app/`, so SpringBoard
(`/System/Library/CoreServices/SpringBoard.app/SpringBoard`) loaded the hook
too. The respring fix described below now excludes system UI services; the
lock-order rule still applies to regular app consumers. Core Motion's
`-[CMMotionManager setDeviceMotionUpdateInterval:]` (and
other methods) hop synchronously to its `com.apple.CoreMotion.MotionThread`,
and blocks on that thread call the public getters, such as
`isDeviceMotionActive`, on the same manager. The first version held the
session lock around the native setter and took it again in the getters. On
iOS 26.6.2 that froze SpringBoard on every boot after data migration: the main
thread builds the Home Screen's parallax (`SBRootFolderView
_updateParallaxSettings` → `_UIMotionEffectCoreMotionEventProvider init`),
which sets the interval, while the MotionThread waits in `VPhoneActive`. The
screen stayed black, Setup.app was killed by its 20 s launch watchdog waiting
for SpringBoard, any vphoned call that needs SpringBoard (`screen.unlock`,
`apps.foreground`, a respring) hung, and template setup boots failed at
setup-skip. 27.0's setter has the same synchronous hop, so the order matters
there as well even though no 27.0 boot was seen to hang.

The rule since: no hooked getter waits for a lock that a caller of a native
method may hold. `active`, `frame` and `latest` are atomic and the getters
read them without the session lock; the setter calls the native method before
it takes the lock; sessions are found through the associated object and
created under a private `os_unfair_lock`, never `@synchronized` on the manager.
`AttitudeLockOrderTests` (part of `make test-attitude`) replaces the native
setter, start and stop with stand-ins that wait for a second thread calling
the getters, and fails without the rule.

### Configuration transport

vphoned serializes publication/readback and persists one dictionary,
`VPhoneAttitudeConfiguration`, in mobile's `com.apple.backboardd` preferences.
It packs angles and enabled in one 64-bit Darwin notification state,
`com.vphone.motion.attitude.changed`. Apps read this atomic state without
cross-sandbox preferences/file access. Transport quantizes to 0.001° (maximum
0.0005° error); persisted/RPC values retain input precision. vphoned seeds
notifyd at startup; new app readers immediately read the latest state.

`provider_installed` only reports the dylib's presence. It does not prove a
target app loaded the hook or received samples. Check SystemHook's app-PID
`attitude-hook=... result=loaded` log and the actual Core Motion consumer.

## Selection and verification

cfw install/update-environment follows selection and records the guest receipt.
No-plan legacy VMs do not opt in. Blocking removes the added file; live hash
sync replaces installed selected copies only. Relaunch apps after changing the
library. A changed SystemHook still requires reboot; no UI daemon is restarted
for attitude updates.

Host checks: `make -C VPhoneGuestComponents test-attitude` tests malformed
configuration, packed-state boundaries, quaternion/matrix/gravity, copy,
relative attitude and secure coding. Its real host Core Motion runtime test
covers all start overloads, polling, callback delivery, live toggle, snapshots,
interval setting, bounded backlog and suppression after stop, using a separate
Darwin notification name. The shared editor harness
`zsh VPhoneExecutable/VPhoneVirtualization/Tests/run-gyroscope-tests.sh` covers
sequencing/retry/reconnect and attitude-specific bounds. Catalogue tests cover
version gating, blocking, preset reachability and manifest invariants.

2026-10-08: sample and live hook tests passed, shared editor tests passed,
55 catalogue/model tests in seven suites passed, and the full VPhone Debug
bundle built successfully. Bundle admission and strict deep signature verification
passed; the built zh-Hans strings include 设备姿态 and 俯仰.

Guest acceptance is manual, as requested: update guest, relaunch a consumer,
enable simulation, compare polling/callback Euler radians, quaternion and
gravity at zero and single-axis 90° poses. Check reset/disable while subscribed,
stopped-manager silence, and relaunch after blocking the patch. Host runtime
checks do not establish guest injection/sandbox acceptance or every app's API.

## SpringBoard respring investigation (2026-10-09)

The reported black screen followed by the Lock Screen is a SpringBoard crash,
not a VM reboot. Reports `SpringBoard-2026-10-09-194121.ips` and
`SpringBoard-2026-10-09-194251.ips` on iOS 27.0.1 (24A446), cloudOS 26.4,
both show `EXC_BAD_ACCESS` / `SIGSEGV` at address `0x10` on
`com.apple.CoreMotion.MotionThread`. The main thread waits in native Core
Motion from `-[VPhoneAttitudeSession stop]`, called by
`startWithFrame:queue:handler:` → `VPhoneStartCallback` → UIKit's
`-[_UIMotionEffectCoreMotionEventProvider startGeneratingEvents]`.
Both reports list `/usr/lib/libvphoneattitude.dylib` in SpringBoard.

The `.app/` injection gate admitted
`/System/Library/CoreServices/SpringBoard.app/SpringBoard`. Separately, every
new simulated subscription called native stop despite never having called
native start. The reports establish that this path reached guest Core Motion
and crashed its motion thread. The console's CloudKit preferences denial,
RunningBoard faults and “No accelerometer” message do not supply the crash
stack; the last message is consistent with the sensorless guest.

Fix: exclude system UI services in both loaders and guard native stop with
the session's native-start tracking. The sensorless lifecycle harness fails
the `stops == 0` assertion before that guard and passes after it. It covers
stop before start, simulated start/restart/stop, repeated stop, native forwarding
of unsupported reference frames, and native-to-simulated switching. Existing
real host hook tests still cover callbacks, polling and live enable/disable.
The upstream MotionThread lock-order regression test passes alongside the
sensorless lifecycle and process-exclusion tests.
Injection tests cover SpringBoard, AccessibilityUIServer, relocated SpringBoard,
Settings and a container-installed consumer.
The lifecycle executable is also run from a `/System/Library/`-shaped
SpringBoard path to verify that the dylib constructor leaves native methods
intact. All host attitude/injection checks and 51 catalogue/model tests in six
suites passed; the attitude and SystemHook dylibs cross-compiled for iPhoneOS.
The full VPhone Debug bundle built successfully, passed bundle admission and
strict deep signature verification.

Deployment acceptance remains pending: build and install the new bundle,
update the stopped guest's environment and boot it. Confirm the new
SpringBoard PID has no `attitude-hook=... result=loaded` entry, enable/edit/
disable attitude while opening/closing apps and locking/unlocking, and check
that no new SpringBoard crash reports appear. Confirm a regular consumer still
receives the expected polling and callback poses. Reboot is needed to apply
SystemHook; replacing a dylib cannot unhook a process that already loaded it.

ABI sources: Xcode iPhoneOS SDK CMMotionManager.h, CMAttitude.h, CMDeviceMotion.h,
system notify.h, Apple [CMAttitude](https://developer.apple.com/documentation/coremotion/cmattitude)
and [CMDeviceMotion](https://developer.apple.com/documentation/coremotion/cmdevicemotion).
No Hopper-derived offset or private initializer is used.
