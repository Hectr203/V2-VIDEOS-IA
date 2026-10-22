// FirmwareGuestPatchResolution.swift — Which guest patches an installed VM should run now.
//
// A VM carries two patch records the guest half of an install reads: the plan
// `fw patch` resolved, and the selection its owner has since edited. They can
// disagree, and which one wins depends on where a patch lands.
//
// A boot-chain patch was built into the restore tree or `FirmwareOriginals` the
// moment `fw patch` ran; the bytes are already in those files, so the plan is
// the truth for them and the current selection cannot change them without
// another `fw patch`. A guest patch is different: nothing writes it until the
// guest half of an install runs, and that half runs every `cfw install` and
// `cfw update-environment`. So a guest patch should follow the current
// selection, which is both what lets `fw set-patches` then `cfw
// update-environment` turn one on and what lets it turn one off.
//
// `VPhoneCustomFirmwareInstaller.withLateGuestPatches` used to do a narrow
// version of this — it merged in a short list of guest patches newer than most
// VMs' plans, and only ever added. This resolves the whole guest half from the
// selection, both directions, and the installer's late-patch list is gone.

import Foundation
import VPhonePatchKit

public enum FirmwareGuestPatchResolution {
    /// Every bundled-set patch whose bytes the guest half of an install writes —
    /// the dyld shared cache, a guest Mach-O, its entitlements, a guest file, or
    /// the Preboot device tree. The complement is the boot chain, which `fw
    /// patch` owns.
    public static var guestTargetIdentifiers: Set<String> {
        Set(
            FirmwarePatchSetCatalog.allDeclarations
                .filter { !$0.target.isBootChain }
                .map(\.identifier),
        )
    }

    /// The identifiers the guest half should apply now: boot-chain patches as
    /// the plan resolved them, guest patches as the current selection resolves
    /// them. A guest patch the plan had on but the selection now blocks drops
    /// out; one the plan never had but the selection now allows comes in.
    public static func effectiveEnabled(
        planEnabled: Set<String>,
        selectionEnabled: Set<String>,
    ) -> Set<String> {
        let guest = guestTargetIdentifiers
        return planEnabled.subtracting(guest).union(selectionEnabled.intersection(guest))
    }

    /// The guest patches a selection leaves off — the ones a run should try to
    /// revert. Boot-chain patches are never here: this is only about the guest
    /// half.
    public static func guestPatchesOff(selectionEnabled: Set<String>) -> Set<String> {
        guestTargetIdentifiers.subtracting(selectionEnabled)
    }
}
