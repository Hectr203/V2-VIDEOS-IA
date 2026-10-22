# Changing a VM's Patches After It Exists

Status: implemented and validated on a test VM 2026-10-04 (branch
`post-creation-patches`). "Current Behaviour" describes `caee5a4` (Release
2.5.0) as read from the code, before this change; "What Was Built" and
"Validation" describe the change.

## The Question

A VM's patches are chosen in the New Machine sheet and Launchpad then calls them
"Fixed once the machine is installed". The CLI does not agree: `fw set-patches`
accepts a change on any VM. This note records what a change made after creation
actually reaches, why, and the plan to make it reach everything it can.

## Current Behaviour

### Three records, no truth

| File | Meaning | Writers | Readers |
| --- | --- | --- | --- |
| `<vm>/PatchSelection.plist` | desired: preset + blocked/allowed boxes | `fw set-patches`, `fw patch`, CLI `vm create` | `fw patch`, `fw patches`, `cfw install` (late guest patches only) |
| `<vm>/PatchPlan.plist` | what the last `fw patch` resolved | `fw patch` | `cfw install`, `cfw update-environment` |
| — | what the guest runs | nobody | nobody |

- `fw set-patches` (`VPhoneFirmwareCommand.swift`, `SetPatches`) has no
  installed check. Its help says the choice applies at the next `fw patch`.
- `fw patches --json` reports the selection only. Nothing compares the
  selection, the plan, or the guest, so drift is silent.
- `PatchPlan.plist` carries no bundle version, no digest, and no evidence that
  `restore` or `cfw install` ever consumed it.
- `withLateGuestPatches` (`VPhoneCustomFirmwareInstaller.swift`) re-resolves 11
  late audio/Preboot patches against the *current* selection, so a
  `set-patches` on an installed VM changes what the next `update-environment`
  turns on, without `fw patch`. It only ever adds; it never turns one off.

### The restore tree is gone by default

`fw patch` needs `*_Restore` (`FirmwarePipelineDiscovery.findRestoreDirectory`
throws "Run vphone-cli fw prepare first"), and a full `cfw install` needs it for
the cryptex images. Launchpad and `cfw install` delete it after the first boot
unless `--keep-artifacts`. `<vm>/FirmwareOriginals/` survives that deletion
(only `*_Restore` is removed, `VPhoneRestoreInfo.removeBuiltFirmware`), so the
pristine boot-chain payloads are still on disk for every VM patched since
2026-09-30.

### Where each patch lands

Counts are declarations in `FirmwarePatcher/PatchSets/*.swift`.

| Part | Patches | Lives in | Reaches the guest by | After creation |
| --- | --- | --- | --- | --- |
| AVPBooter | 1 | VM root, `romImages.avpBooter`, read every boot | `fw patch` itself | works, but `fw patch` refuses without a restore tree |
| iBSS, iBEC | 7 | restore tree only | DFU during a restore | irrelevant to an installed guest; only the next restore uses them |
| LLB | 6 | NOR (personalized by idevicerestore, `LlbImageData`) | restore | needs a restore, which erases the guest: an in-place one cannot keep its data (`native_restore_architecture.md`, 2026-10-05) |
| kernelcache | 54 | Preboot (personalized) | `cfw update-kernel` | Host-mounts Preboot and swaps the kernelcache IM4P under the original IM4M (the image4 bypass), data-preserving, no restore |
| DeviceTree, TXM | 30 + 6 | Preboot (personalized) | restore | Preboot can be rewritten by a host mount (as the kernelcache now is); not yet wired for these two |
| Guest (dyld cache, Mach-O, files, entitlements, Preboot DT) | 34 | System / Preboot volumes of `Disk.img` | `cfw install`, partly `cfw update-environment` | turning on works by re-running; turning off does nothing |

Why turning a guest patch off does nothing today:

- **dyld shared cache** — patched in place, no backup. The verbs are no-ops on
  patched bytes but have no inverse. The only reset is emptying
  `System/Cryptexes/{OS,App}` so `installCryptexes` copies them again, which
  needs the restore tree.
- **Mach-O** — always re-patched from `<path>.bak`, then re-signed. When the
  patch is off the step is skipped and the patched file stays. Reverting is a
  copy back from `.bak`.
- **Preboot device tree** — edited on a staged copy and written back, with no
  backup of the personalized `devicetree.img4`.
- Only VirtualAudio has an explicit restore-from-`.bak`, in `update-environment`.

Why rewriting Preboot boots at all: the iBSS/iBEC/LLB image4 callback bypass
accepts a modified IM4P payload under the original IM4M
(`CustomFirmwarePostRestoreDeviceTree.swift` header,
`firmware_manifest_and_origins.md`). The same bypass is what a kernelcache swap
would rely on; confirm whether the stage that loads the kernelcache is covered
before shipping it.

### Bundle rebinding

`vm set-bundle` changes only the binding. Afterwards `fw patches`/`fw patch`
resolve against the new bundle's catalogue; an identifier renamed since then
makes `fw patch` throw `unknownPatch` (no migration), and `update-environment`
may turn on late guest patches the new catalogue declares.

## What Was Built

The design keeps the existing layers and adds one record:
`<vm>/PatchReceipt.plist`, `VPhoneVirtualMachinePatchReceipt` in
`VPhonePatchPresetStore.swift`. It is keyed by part — a
`VPhoneFirmwareComponent.rawValue` for boot-chain patches, `Guest` for
everything `cfw install` writes — and each step that puts patched bytes into the
guest replaces the parts it wrote, recording the enabled identifiers, the verb,
the bundle version and the date. A part a step wrote with nothing on is recorded
empty, so "reverted" and "unknown" differ. A VM with no receipt is unknown, not
empty. `NotApplicable` lists selected patches the guest has nothing for (the
board audio repair on an iPhone, the build spoof with no value), which never
count as drift.

| Step | Parts it records |
| --- | --- |
| `restore` (success) | `iBSS`, `iBEC`, `LLB`, `TXM`, `kernelcache`, `DeviceTree` from `PatchPlan.plist`, and `Guest` as empty (the system volume is re-imaged) |
| `cfw install`, `cfw update-environment` | `Guest` |

Nothing records `AVPBooter`; its drift is measured against the plan.

**Report and guard.** `fw patches <vm>` compares selection, plan and receipt per
patch; `--json` adds `part`, `wanted`, `planned`, `applied`, `pending`,
`delivery` per patch and `planRecorded`, `receiptRecorded`, `receiptParts`,
`installed`, `pendingPatches` at the top, only when a VM is named, so a 2.5
Launchpad and bundle stay interchangeable. The rule is `FirmwarePatchDrift`.
`fw set-patches` on an installed VM lists each differing patch with the step that
delivers it. Launchpad's inspector shows preset, overrides and a "Not Applied"
count read-only, through the machine's bound bundle.

**Guest patches both ways.** The guest half resolves from the current selection
(`FirmwareGuestPatchResolution`); the boot-chain half stays as `fw patch` built
it. `cfw install` and `cfw update-environment` apply what is on and revert what
is off:

- Mach-O, entitlement and guest-file patches restore from the `.bak` beside the
  file. debugserver, Campo, the build spoof and the VirtualAudio tunings now take
  one before their first write.
- The Preboot device tree keeps `devicetree.img4.bak` beside it, the
  post-identity, pre-repair tree. A run rebuilds the tree from it in staging and
  writes only when the bytes differ, so an unchanged run does not move the mtime
  vphoned's MobileGestalt cache check reads.
- The dyld cache gets an undo log, `.vphone-dsc-undo.json` in the cache
  directory, with the original bytes of every content write
  (`DyldSharedCacheUndoLog`, captured by `DyldSharedCacheChunkSet`). Slot hashes
  are not logged: a revert puts the bytes back and re-attests the page, which is
  right even when two patches share one. A re-run that writes nothing keeps the
  records; every record is validated before anything is written.
- A first backup is taken only when no patch touching that file is live, so a
  backup never captures patched bytes. Where there is none, the patch is
  reported not revertible and stays live in the receipt. On a VM installed
  before this change that is every dyld patch and every multi-edit file.
- Only dyld patches whose state changes are touched, so an unchanged
  `update-environment` does no cache scan. A failing patch is reported, keeps
  its previous state in the receipt, and does not stop the run or the vphoned
  redeploy. The environment-library rule for `update-environment` is as before.

"Prior live" is the receipt's `Guest` part; for a VM with none, the plan's guest
patches plus the late ones the old installer added.

**The kernel reaches an installed guest without a restore.** `cfw update-kernel`
host-mounts Preboot and swaps in a re-patched kernelcache under the original
signed IM4M — iBoot accepts it, the same image4 bypass that lets `cfw install`
rewrite `devicetree.img4` there — so no volume is reformatted and the data
survives. It re-patches the pristine kernelcache kept in `FirmwareOriginals`
with the VM's current selection, so it needs no restore tree and no prior
`fw patch`: flow is `fw set-patches` (or the Launchpad patch editor) then
`cfw update-kernel` (proven on test VMs 2026-10-05, including a VM with no
restore tree — guest booted the re-patched kernel with its
`/var/mobile/Documents` marker intact). TXM and
DeviceTree live in Preboot too and could follow; the kernelcache was done first
because a kernel patch is the common reason to change the boot chain.

**A restore still erases, so the rest of the boot chain needs one.** TXM,
DeviceTree, LLB, iBSS and iBEC change only through a restore, and AVPBooter only
through `fw patch`. `restore --no-erase` cannot keep data: tried on a test VM on
2026-10-05, restored in the cloudOS ramdisk repartitions whatever the host
sends, so it now refuses (row 4 and "An in-place restore cannot keep a guest's
data" in `Research/Restore/native_restore_architecture.md`).

**Paired DeviceTree patches.** `devicetree-cfw-ipad_audio`,
`devicetree-cfw-product_haptics_node` and
`devicetree-cfw-product_audio_microphone_array` write into the tree a restore
installs; `preboot-cfw-devicetree_board_audio`, `_haptics` and
`_microphone_array` write the same change into the Preboot tree of a VM restored
before them. `FirmwareGuestSystemPatchSet.prebootRepairs` names the pairs, and
the drift report reads the tree patch as applied when its Preboot repair is
live, so a VM restored before the tree patches no longer shows them as needing
a restore. The Launchpad inspector says in the open how many boot-chain patches
are pending and that a kernel patch applies with `cfw update-kernel` (keeping the data) while the rest need a restore that erases.

## Validation (2026-10-04)

`patchtest-iphone`, iPhone 27.0 24A435 + cloudOS 26.4, `--keep-artifacts`,
driven through Launchpad (`vm set-bundle … --update-environment` runs the helper's
root `cfw update-environment`).

Installed by 2.5.0, then updated with this build:

1. First update: no dyld patch touched, `Guest` recorded, guest boots, vphoned
   answers.
2. `--block system-diskimagesiod-cfw-is_mount_complete --block dyld-cfw-camera`,
   update: diskimagesiod restored from `.bak` and dropped from the receipt; the
   camera patch reported "patched before the undo log existed; not revertible"
   and kept live. Guest boots.

Created by this build:

3. Fresh VM: receipt has `iBSS`…`DeviceTree` and `Guest`; `fw patches` reports
   no drift. The undo log holds records for the six applied dyld patches.
4. `--block dyld-cfw-camera --block preboot-cfw-devicetree_microphone_array`,
   update: both leave the receipt, the camera's records leave the undo log, the
   guest boots and vphoned answers (the reverted pages re-attested correctly).
5. Back to the preset, update: both return to the receipt, the camera's six
   records are back, the guest boots, `fw patches` reports no drift.

Not checked live: the Launchpad inspector (build only; a Debug Launchpad must
run in snapshot mode), the identity rewrite on a re-run full install, and the
helper's console log, which on these runs kept little or none of
`update-environment`'s standard output, so the evidence above is the receipt,
the undo log read through vphoned's `files.read`, and boots.
