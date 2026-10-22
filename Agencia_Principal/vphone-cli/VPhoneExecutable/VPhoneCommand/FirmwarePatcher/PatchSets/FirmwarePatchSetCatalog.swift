// FirmwarePatchSetCatalog.swift — The patch sets built into the bundle.
//
// These are the sets a preset can name as `Bundled`. They are compiled in rather
// than loaded, so `cfw install` running as root never has to open a file to learn
// what the bundle's own patches are — an external `.vphonepatchset` is the only
// thing that has to be imported and pinned first.

import Foundation
import VPhonePatchKit

public enum FirmwarePatchSetCatalog {
    /// Every bundled set, in the order the pipeline would run them.
    public static let bundled: [VPhonePatchSetManifest] = [
        FirmwareBootChainPatchSet.manifest,
        FirmwareKernelBasePatchSet.manifest,
        FirmwareKernelCustomFirmwarePatchSet.manifest,
        FirmwareKernelHypervisorPatchSet.manifest,
        FirmwareKernelFridaPatchSet.manifest,
        FirmwareDeviceTreePatchSet.manifest,
        FirmwareGuestSystemPatchSet.manifest,
        FirmwareGuestDisplayPatchSet.manifest,
        FirmwareGuestIdentityPatchSet.manifest,
    ]

    /// Every bundled set, as a preset references them.
    ///
    /// Both shipped presets name all of them. A preset picks patches with its
    /// selection, not by leaving a set out, so the editor always sees the whole
    /// catalogue and can turn any patch on or off.
    public static let bundledReferences: [VPhonePatchSetReference] =
        bundled.map { .bundled($0.identifier) }

    public static func manifest(identifier: String) -> VPhonePatchSetManifest? {
        bundled.first { $0.identifier == identifier }
    }

    /// Every declared patch across every bundled set.
    public static var allDeclarations: [VPhonePatchDeclaration] {
        bundled.flatMap(\.patches)
    }

    // MARK: - Built-in Presets

    /// Patches that are declared but off unless someone asks for them.
    ///
    /// The Frida relaxations widen what any process in the guest may do and
    /// nothing needs them to boot, so `standard` leaves them off. They stay in the
    /// catalogue, version-gated like everything else, and a VM can check them on.
    ///
    /// The hypervisor concealment pair is off for a harder reason: it stops a
    /// freshly restored 26.4 guest booting at all. See
    /// ``hypervisorConcealmentPatches``. The rest of the former EXP variant is
    /// off with it, bar the camera: see ``experimentalIdentityPatches``.
    ///
    /// `dyld-exp-mis_trust_auth` is off because a userspace hook now does its
    /// job: see ``misTrustAuthPatch``.
    ///
    /// `kernel-cfw-paravirt_user_clients` and `kernel-cfw-display_promotion`
    /// are not in this list: `standard` turns them on. See
    /// ``paravirtUserClientsPatch`` and ``proMotionPatch``.
    public static let manualOnlyPatches: Set<String> =
        Set(FirmwareKernelFridaPatchSet.manifest.patches.map(\.identifier))
            .union(hypervisorConcealmentPatches)
            .union(experimentalIdentityPatches)
            .union([misTrustAuthPatch, FirmwareGuestSystemPatchSet.settingsRootRows, FirmwareGuestSystemPatchSet.settingsSoftwareUpdate])

    /// ProMotion: the 120 Hz timing for the paravirtual display.
    ///
    /// On in `standard`. The host's mode is 60 Hz and Virtualization has no
    /// setting for it; the guest renders at whatever rate the timing element
    /// advertises, and the host scans out every frame it presents. A guest
    /// rendering twice as often costs up to twice the host CPU and GPU while it
    /// animates, and nothing while it is static. Blocking it per VM keeps 60 Hz.
    ///
    /// Introduced opt-in as `kernel-exp-display_refresh_120hz`, which shipped from
    /// 2.4.2; renamed `kernel-cfw-display_promotion` when `standard` turned it on,
    /// as the naming rule requires. ``renamedPatches`` maps a VM's record of the
    /// old name. See
    /// `Research/Guest/display_refresh_rate.md`.
    public static let proMotionPatch = "kernel-cfw-display_promotion"

    /// Identifiers a released bundle declared that a later one renamed, old to new.
    ///
    /// A VM's `PatchSelection.plist` and `PatchReceipt.plist` outlive the bundle
    /// that wrote them, and `fw patch` throws `unknownPatch` for an identifier
    /// nothing declares. Only renames that reached a release are listed: one that
    /// never left a development branch has no record to carry.
    public static let renamedPatches: [String: String] = [
        "kernel-exp-display_refresh_120hz": proMotionPatch,
    ]

    /// The identifiers this bundle declares for ones a VM recorded, in order, each
    /// once.
    public static func currentIdentifiers(_ identifiers: [String]) -> [String] {
        var seen = Set<String>()
        return identifiers
            .map { renamedPatches[$0] ?? $0 }
            .filter { seen.insert($0).inserted }
    }

    /// A narrow IOUserClient sandbox allowlist for the paravirtual devices, on a
    /// base older than 27.
    ///
    /// A 26.x sandbox knows nothing of the research board's paravirtual devices,
    /// so only an app's container profile lets a process open them. A daemon or a
    /// command-line tool gets no Metal device, WebKit no hardware video decoder,
    /// and Core ML no Neural Engine. The edit allows only the four paravirt device
    /// classes, by name, and leaves every other denial in place.
    ///
    /// On in `standard`. `cameracaptured` prewarms its capture shaders on the GPU at
    /// every boot; refused the device, it crashes inside the paravirtual Metal
    /// driver and crash-loops, and the first process to touch AVCapture blocks on a
    /// synchronous XPC to it — SpringBoard's main thread when a guest app starts
    /// recording. What it widens is four class-name prefixes of devices apps already
    /// open, to processes outside an app sandbox, on a research VM.
    ///
    /// Introduced opt-in as `kernel-exp-paravirt_user_clients`; renamed `cfw` when
    /// `standard` turned it on, as the naming rule requires.
    /// On 27 the broad `kernel-boot-iouc_sandbox_gate` is boot-essential instead. See
    /// `Research/Guest/gpu_acceleration.md`.
    public static let paravirtUserClientsPatch = "kernel-cfw-paravirt_user_clients"

    /// The shared-cache short-circuit of `libmis`'s `checkTrustAndAuthorization`.
    ///
    /// Off in `standard` because `libmisfix.dylib` reaches the same outcome from
    /// userspace without editing the cache. The hook passes
    /// `RespectUppTrustAndAuthorization = false` in the options dictionary, and
    /// libmis only calls `checkTrustAndAuthorization` when that flag is set, so
    /// `0xE8008026` — "missing trust and/or authorization", which a hacktivated
    /// guest with no activation record can never satisfy — is never produced.
    /// The spawn hooks insert it into `installd`, `misagent` and `SpringBoard`.
    ///
    /// Leaving the patch on costs more than it buys. On iOS 27 it stops the guest
    /// booting: TXM rejects the re-attested page, dyld cannot map
    /// `libSystem.B.dylib`, and `initproc failed to start` (issue #532). On 24A435
    /// it cannot even be applied — `checkTrustAndAuthorization` there carries
    /// neither the seeding prologue the patcher matches nor the patcher's own
    /// output, so `cfw install` fails outright before it writes anything.
    ///
    /// Why it stays declared rather than being deleted: on a 26.x guest whose
    /// environment predates SpringBoard getting the hook, an installed app is
    /// refused at launch, and this box is an alternative to updating the
    /// environment. On 27 it is not offered.
    public static let misTrustAuthPatch = "dyld-exp-mis_trust_auth"

    /// The former EXP patches that make the guest claim to be an iPhone17,3.
    ///
    /// `standard` is the JB baseline plus the camera. The camera needs the device
    /// tree's `/product/camera`, ISP and SMC nodes and `dyld-cfw-camera`, which stay on;
    /// it does not need the identity rewrites. They shipped on with the hypervisor
    /// concealment when EXP joined the JB flow, and guests from that build lost
    /// location (issue #438), so they go back to opt-in with it. `extended` or a
    /// per-VM checkmark turns them back on.
    public static let experimentalIdentityPatches: Set<String> = [
        "devicetree-exp-target_sub_type",
        "devicetree-exp-compatible_secondary",
        "devicetree-exp-product_fdr_product_type",
        "devicetree-exp-product_sub_product_type",
        "devicetree-exp-product_unique_model",
        "devicetree-exp-product_gestalt_variants_rename",
        "devicetree-exp-arm_io_device_type",
        "devicetree-exp-arm_io_soc_generation",
        FirmwareGuestIdentityPatchSet.prebootDeviceTreeIdentity,
    ]

    /// The `hv_vmm_present` concealment, which is one patch in everything but name
    /// and has to be selected as a whole.
    ///
    /// Renaming the OID without mangling the shared cache breaks the graphics and
    /// ML paths; mangling the cache without the rename does nothing. watchdogd
    /// caches the sysctl at startup and, when the renamed OID returns ENOENT,
    /// reaches a `brk` that launchd turns into a panic, so its patch goes with the
    /// rename and is pointless without it. All three are off
    /// in `standard` because on a freshly restored 26.4 guest the rename makes
    /// `bluetoothd`'s cached `kern.hv_vmm_present` lookup fail, which sends it down
    /// the `MGIsDeviceOneOfType` path, leaves its transport singleton NULL and
    /// crash-loops it until launchd throttles it; `locationd` then blocks on the
    /// throttled Bluetooth XPC service, the data migrator hangs, and SpringBoard
    /// waits on migration forever — a black screen with no panic. See
    /// `Research/Patches/hv_vmm_present_usermode_xrefs.md`.
    public static let hypervisorConcealmentPatches: Set<String> = [
        "kernel-exp-hv_vmm",
        "dyld-exp-hv_vmm",
        "system-watchdogd-exp-hv_vmm_cache",
    ]

    /// The preset a VM gets when nothing else is named.
    ///
    /// The shipped `standard.plist` must match this; `FirmwarePatchSetTests`
    /// checks that it does. This copy is what a dev build with no staged
    /// `patches_presets` directory falls back to, so `fw patch` works straight out
    /// of an Xcode build.
    public static let standardPreset = VPhonePatchPreset(
        identifier: VPhonePatchPreset.standardIdentifier,
        title: "Standard",
        summary: "The patches every vphone VM needs to boot custom firmware, with a working display and camera.",
        patchSets: bundledReferences,
        selection: .block(manualOnlyPatches),
    )

    /// Everything the bundle declares, including the Frida relaxations, the
    /// hypervisor concealment and the iPhone17,3 identity. Each patch's own version
    /// gate still decides whether it lands.
    public static let experimentalPreset = VPhonePatchPreset(
        identifier: "experimental",
        title: "Experimental",
        summary: """
        Every patch this bundle declares, including the Frida Stalker relaxations, \
        the iPhone17,3 identity rewrites, and the hv_vmm_present concealment that a \
        freshly restored 26.4 guest does not survive.
        """,
        patchSets: bundledReferences,
        selection: .all,
    )

    /// The presets the bundle ships.
    public static let builtInPresets: [VPhonePatchPreset] = [standardPreset, experimentalPreset]
}
