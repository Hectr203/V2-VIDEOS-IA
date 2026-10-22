# Firmware compatibility

[Documentation](../README.md) · [Create a VM](create-and-run.md) · [Patch inventory](../../Research/0_binary_patch_comparison.md)

**v2.0.0 VM format:** This release starts only newly created VMs whose
`config.plist` has `schemaVersion=2`. Recreate VMs made by earlier releases
with `vm create`; there is no in-place upgrade. The firmware results below
describe tested pairings, not compatibility with older VM bundles.

## Tested Environments

These are the two iPhone17,3 combinations exercised with the native JB pipeline in [PR #486](https://github.com/Lakr233/vphone-cli/pull/486). Both reached the lock screen and answered a vphoned ping. A fresh 26.6.2 `vm create` also completed all stages and exited successfully after its first-boot ping.

| Validation | iPhone restore IPSW | PCC/cloudOS IPSW | Observed result |
| --- | --- | --- | --- |
| PR #486 | `17,3_26.6.2_23G90` | `26.4-23E5207q` | JB patches, restore, CFW, boot, vphoned ping |
| PR #486 | `17,3_27.0_24A435` | `26.4-23E5207q` | JB patches, restore, CFW, boot, vphoned ping |

The cloudOS 26.4 beta image (`26.4-23E5207q`) is the newest one that contains `vphone600ap`, the identity the guest's kernel, SEP and device tree come from. Every cloudOS release after it was checked on 2026-10-03 and lists only the PCC boards and `vresearch101ap`: `iPhone99,11` is gone from `SupportedProductTypes`, and there is no `kernelcache.*.vphone600`, `sep-firmware.vphone600` or `DeviceTree.vphone600ap`. None of them can boot a guest; `fw prepare` refuses them before extracting anything.

| cloudOS | `vresearch101ap` | `vphone600ap` |
| --- | --- | --- |
| `26.4-23E5207q` (beta) | yes | yes |
| `26.4-23E244` | yes | no |
| `26.4.1-23E254` | yes | no |
| `26.5-23F75` | yes | no |
| `26.5.2-23F83` | yes | no |
| `26.6-23G71` | yes | no |
| `26.6.1-23G82` | yes | no |
| `26.7-23H20` | yes | no |

Use `vphone-cli fw catalog` to inspect the current catalogue. Other iPhone and iPad versions may work with `26.4-23E5207q`, but they have not passed this same end-to-end check.

**iPhone17,3 27.0.1 (24A446)** fails first boot on bundle 2.5.0 and earlier
(reproduced 2026-10-04, including with the pristine Apple launchd): TXM's
selector-24 pre-check rejects every binary at init and the boot panics with
`unexpected SIGKILL of init`. The `txm-boot-precheck_admission` patch
(`Research/Firmware/txm_selector24_cms_gate.md`) fixes it; verified the same
day: `iPhone17,3 27.0.1 + 26.4-23E5207q` with the patch boots to the guest
and answers a vphoned `device.info`. Bundle 2.6.0 is the first release that
carries it.

## Other iPhone models

See [Other iPhone models](iphone-models.md).

| Host | iPhone restore IPSW | PCC/cloudOS IPSW | Observed result |
| --- | --- | --- | --- |
| Mac17,9 (M5 Pro) 27.0.1 | `18,1_26.6.2_23G90` (iPhone 17 Pro) | `26.4-23E5207q` | Launchpad `vm create` (2.5.1 local bundle): prepare, patch, restore, CFW, boot to the home screen at 402x874 pt @3x, `model` iPhone18,1, vphoned ping |
| Mac17,9 (M5 Pro) 27.0.1 | `18,2_27.0.1_24A446` (iPhone 17 Pro Max) | `26.4-23E5207q` | **boots** with the `kernel-boot-shared_region_size` patch (2026-10-06, bundle 2.6.0-local.0d5e6f90): `dyld cache mapped system-wide`, 0 panics, vphoned answers as 27.0.1, home screen at 440x956 pt @3x |

**iPhone18,1 and iPhone18,2 on iOS 27 need the shared-region patch**
([issue #596](https://github.com/Lakr233/vphone-cli/issues/596), 27.0 and
27.0.1). Their dyld shared cache records a `sharedRegionSize` of
`0x185804000` on 27.0.1, larger than the `0x180000000` shared region of the
cloudOS 26.4 guest kernel, so it cannot map even with `dyld-boot-maxslide`
taking its slide away: launchd panics on first boot with `Library not loaded:
/usr/lib/libSystem.B.dylib`. iPhone17,3's 27.0.1 cache (`0x17D508000`) still
fits. Since this check, `cfw install` refuses such a cache with that
explanation instead of leaving a guest that panics.

`kernel-boot-shared_region_size` (on in `standard` for an iOS 27 base since
2026-10-06) widens the arm64 region to `0x1C0000000` — the largest size that
stays under the 26.4 kernel's own task-map ceilings — and `cfw install`
measures the cache against that widened region when the VM's kernel carries
the patch (its `PatchReceipt.plist` says so), so these devices now install and
boot; validated on iPhone18,2 27.0.1 as above. Without the patch
(an older bundle, or the patch unticked) the refusal stands: use iPhone17,3
for iOS 27, or iOS 26 on these devices.

## iPadOS

See [iPadOS guests](ipados.md).

| Host | iPad restore IPSW | PCC/cloudOS IPSW | Observed result |
| --- | --- | --- | --- |
| Mac17,9 (M5 Pro) 27.0.1 | `iPad16,1,iPad16,2_26.6.2_23G90` | `26.4-23E5207q` | prepare, patch, restore, CFW (2.2.5 helper), boot to the iPadOS home screen at 744x1133 pt @2x, `model` iPad16,1, vphoned ping |
| Mac17,9 (M5 Pro) 27.0.1 | `iPad16,1,iPad16,2_27.0.1_24A446` | `26.4-23E5207q` | Launchpad `vm create --device iPad16,1` from the catalog (2.4.0 bundle): prepare, patch, restore, CFW, boot to the iPadOS home screen at 744x1133 pt @2x, `model` iPad16,1, `ios_version` 27.0.1, vphoned ping |

## Earlier reported combinations

The previous README recorded the following host and firmware pairings. They predate the current single-mode flow or lack the same vphoned acceptance evidence, so treat them as research history rather than the current support matrix.

| Host            | iPhone                | CloudOS         |
| --------------- | --------------------- | --------------- |
| Mac16,11 27.0b2 | `17,3_18.6.2_22G100`  | `26.1-23B85`    |
| Mac16,8 26.5.1  | `17,3_26.0_23A341`    | `26.1-23B85`    |
| Mac16,8 26.5.1  | `17,3_26.0.1_23A355`  | `26.1-23B85`    |
| Mac16,12 26.3   | `17,3_26.1_23B85`     | `26.1-23B85`    |
| Mac16,12 26.3   | `17,3_26.3_23D127`    | `26.1-23B85`    |
| Mac16,12 26.3   | `17,3_26.3_23D127`    | `26.3-23D128`   |
| Mac16,12 26.3   | `17,3_26.3.1_23D8133` | `26.3-23D128`   |
| Mac16,11 26.2   | `17,3_26.4_23E246`    | `26.4-23E5207q` |
| Mac16,11 26.2   | `17,3_26.5_23F77`     | `26.4-23E5207q` |
| Mac16,11 27.0b2 | `17,3_26.5.2_23F84`   | `26.4-23E5207q` |
| Mac16,6 26.4.1  | `17,3_26.6_23G71`     | `26.4-23E5207q` |
| Mac16,11 27.0b2 | `17,3_26.6.1_23G83`   | `26.4-23E5207q` |
| Mac16,6 26.6.1  | `17,3_26.6.2_23G90`   | `26.4-23E5207q` |
| Mac16,11 27.0b2 | `17,3_27.0_24A5380h`  | `26.4-23E5207q` |
| Mac16,6 26.4.1  | `17,3_27.0_24A5390f`  | `26.4-23E5207q` |
| Mac16,6 26.6.1  | `17,3_27.0_24A5408d`  | `26.4-23E5207q` |
| Mac16,11 27.0b2 | `17,3_27.0_24A5418b`  | `26.4-23E5207q` |
| Mac16,11 27.0b2 | `17,3_27.0_24A5424a`  | `26.4-23E5207q` |
| Mac16,11 27.0b2 | `17,3_27.0_24A5430a`  | `26.4-23E5207q` |
| Mac16,6 26.6.1  | `17,3_27.0_24A435`    | `26.4-23E5207q` |
