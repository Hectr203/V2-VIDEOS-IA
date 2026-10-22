# iOS 27 locationd startup crashes and cohort queues

Disabling `CoreLocation/CLAutoCohort` prevents the startup PAC failures and
queue hangs reproduced on iOS 27.0 (24A435) and iPadOS 27.0.1 (24A446) guests
using the cloudOS 26.4 (23E5207q) research kernel. This is a compatibility
workaround: the underlying libdispatch/kernel defect has not been established.
The existing locationd watchdog remains as a recovery mechanism.

`system-locationd-cfw-disable_auto_cohort` sets only `CLAutoCohort.Enabled`
to `false` in `/System/Library/FeatureFlags/Domain/CoreLocation.plist`.
The guest system patch set selects it only for an iOS 27 base. The installer
backs up the original plist and restores it when the patch is deselected.
Other feature flags and the plist encoding are preserved. No executable,
PAC instruction, or kernel instruction is changed.

See also [the earlier startup-deadlock investigation](locationd_startup_deadlock.md).

## Evidence and fault location

The supplied 24A446 crash report records locationd PID 413 launching at
20:12:26.088 and crashing at 20:12:26.165 on October 8, 2026 (report timezone
+0900). Thread 8 is draining `Cohort:0` and terminates with
`EXC_ARM_PAC_FAIL`. The failure occurs about 77 ms after launch.

The libdispatch UUID is `8CDF4610-F6A5-39CB-94BF-687FE349A4BE`. Its base is
`0x1aeaf1000`, and the faulting PC is `0x1aeafb6b8`, an image-relative offset
of `0xa6b8`. The original 24A435 cache contains the same UUID at base
`0x1aeaee000`, placing the corresponding instruction at `0x1aeaf86b8`.
Match the image UUID and relative offset rather than assuming identical
cache layouts.

The instruction is `autda x16, x17` in `_dispatch_lane_serial_drain + 192`:

```text
ldr   x28, [x25]
cmp   x28, #0x1, lsl #12
b.lo  <continuation path>
mov   x16, x28
mov   x17, x25
movk  x17, #0x6ae1, lsl #48
autda x16, x17                 // fault
```

The report has `x25 = 0x0000000dd9385fe0`, `x28 = 0x00000001e0174ac8`, and
`x17 = 0x6ae1000dd9385fe0`. Authentication fails while interpreting the first
word of the queue-head object, before the subsequent indirect call. This
is distinct from the earlier report of a bad block invoke pointer. A stale
stack continuation is a candidate explanation, not a proven origin of the
corruption.

| Evidence | Observation | Interpretation |
| --- | --- | --- |
| `locationd-20261008-201345-spinning.spindump.txt` | PID 533 consumes 3.202 s CPU in a 3.22 s sample. The main thread waits on CLLocationControllerSilo; another thread loops through `_dispatch_lane_drain_barrier_waiter` and `__DISPATCH_WAIT_FOR_ENQUEUER__`. | Sustained enqueuer waiting accompanies the blocked main thread. The sample does not identify the original corrupting write. |
| `locationd-20261008-201523.spindump.txt` | Contains PIDs 671, 674 and 676; PID 671 becomes a zombie, while PID 676 again blocks the main thread. | This is a sequence of process lifetimes, not one stable process sample. |
| `panic-vm-27.0.1.log` | `VM entry ... lock is invalid (0)` at `vm_entry_lock.c:168`; the panicked task is inspectord, PID 485. | A separate kernel panic is confirmed, but direct causation by locationd is not established. |

## Configuration path

Static inspection used ipsw and llvm-objdump on original firmware. locationd
loads LocationSupport, CoreLocation and libSystem. Relevant LocationSupport
imports include `_os_feature_enabled_impl`,
`dispatch_queue_create_with_target$V2` and the Objective-C runtime.

In 24A435 locationd, the code at `0x100420c60` reads `CLSilo.Version`.
An older configuration version clears the saved cohort overrides; the
built-in version is 1. The code at `0x100420ef4` reads
`CLSilo.NameToCohortMap`, and `0x100420f9c` calls
`+[CLSilo setGlobalConfiguration:]`. It also reads `CLSilo.SyncgetGraphFile`.

LocationSupport's
`+[CLAutoCohortUtilities enableAutoCohortingForProcessAtPath:]` queries
`CoreLocation/CLAutoCohort` at `0x23984b1b0`. With the flag disabled, the
silos retain independent serial queues instead of automatic cohort targets.
Both tested builds contain the same feature dictionary, initially containing
only `DevelopmentPhase = FeatureComplete`.

A user-directory override under `/Library/Preferences/FeatureFlags/Domain`
did not produce confirmed disablement. The successful experiment changed
the system feature plist and rebooted. Logs explicitly reported
`CoreLocation/CLAutoCohort=off`, and silo `CohortId` values were empty.
An empty sync-get graph was briefly configured but never used in a completed
controlled startup; it was removed and is not counted as a test result.

## Guest validation

Tests ran on October 8, 2026 with 8 vCPUs, 8 GiB RAM, the standard preset,
cloudOS 26.4 (23E5207q), and bundle `2.7.0-local.b16edda9`.
The configuration change was applied manually to isolate it from unrelated
local bundle changes. PatchReceipt was not edited to claim an installer run.

| Guest | Build | With automatic cohorts | With automatic cohorts disabled |
| --- | --- | --- | --- |
| `loc27-iphone`, iPhone17,3 | 27.0 / 24A435 | Restoring the original flag brought back missing-PID startup checks, 18 accumulated launch attempts and a watchdog kill of unresponsive PID 456. | 20/20 locationd restarts and 5/5 complete VM stop/start cycles responded in under 1 s, with unchanged PID across each probe. |
| `loc27-24a446`, iPad16,1 | 27.0.1 / 24A446 | Fresh installation reproduced a crash loop. An 8 s probe timed out. A new crash had `Cohort:0`, `EXC_ARM_PAC_FAIL`, and `_dispatch_lane_serial_drain + 192`, matching the supplied report. | Another 20/20 restarts and 5/5 cold boots responded in under 1 s. No new crash reports or watchdog actions appeared. |

For each process-restart trial, kill locationd with SIGKILL, wait 3 s, record
its replacement PID, issue `location.current` with an 8 s host timeout, then
check the PID again. For each cold-boot trial, stop/start the VM, wait for
vphoned, and perform the same probe before watchdog recovery can intervene.
A PID change or missing PID is not a successful probe.

Location Services remained off throughout. The expected immediate response
was `Location Services are turned off in the guest`; this exercises startup
and synchronous daemon responsiveness. It does not validate Maps navigation
or complete simulated-coordinate delivery.

On 24A446, the first baseline capture contained seven new reports; outstanding
report writes had completed by the repaired-run baseline, which contained
13. The sorted locationd report entries, including paths and modification
metadata, were identical before and after the repaired trials. The two
existing watchdog log entries did not increase. A separate instrumented
restart confirmed the disabled-feature log message. The guest ended with
`panicked=false`.

Original configuration backups were retained as `CoreLocation.plist.bak`
and checked against the pre-change dictionary. Temporary launchd jobs were
unloaded and removed. After reboot, `/sbin/mount` confirmed the root volume
was `apfs, sealed, local, read-only`. Backups belong on the persistent system
volume: `/var/tmp` was cleared during an earlier reboot, invalidating one
attempted reverse-control setup; that attempt is excluded from the results.

### Preparing the 24A446 guest

The initial online restore failed before locationd could run. The guest's
AEA key retrieval received an HTTP 301, then reported
`No WKMS decryption key received from host` and ASR error 1106. After that
restore exited, restarting the test guest in DFU, fetching its ticket with
`restore --get-shsh`, and running the existing `restore --offline` path
completed host-side AEA decryption, filesystem transfer and sealing.
`cfw install` then completed successfully. These preparation failures are
separate from the locationd test results.

## Source and build verification

The configuration and catalogue suites passed 21 tests, covering XML and
binary format preservation, unrelated flags, dry-run, idempotence, malformed
schema rejection, and selection for iOS 27 only (including unknown-version
exclusion). The complete Debug VPhone bundle build and bundle admission
passed. Its CLI also patched a copy of the original 24A446 feature plist;
dry-run left the input unchanged, and a second real run preserved the
first run's output byte for byte.

The guest experiments establish a compatibility workaround for these two
builds. They do not prove which underlying libdispatch or kernel operation
causes the race, nor that other iOS 27 builds are unaffected by other faults.

## Original report integrity

The source reports were not modified. Hashes identify the original inputs;
the reports themselves are not included in the repository.

| File | SHA-256 |
| --- | --- |
| `panic-vm-27.0.1.log` | `cedfac427321fecbf28ebc2c8c4be7081f0b3e6998cde57e08551bff36185081` |
| `locationd-20261008-201523.spindump.txt` | `3c3fc7ac15b18da40fa307b38a53359d518ef5b506f2d087b14a7e86843b2ec7` |
| `locationd-20261008-201345-spinning.spindump.txt` | `de3c523b1d14457cacf3aa4e56af73a8147c16af8667f506f8356470ac5d9656` |
| locationd xrashreport, October 8, 2026 at 20:12:26 | `2401fd41e798c5776ee1b1bea03c49b317430a98e0798f35857212a2f6f56075` |
