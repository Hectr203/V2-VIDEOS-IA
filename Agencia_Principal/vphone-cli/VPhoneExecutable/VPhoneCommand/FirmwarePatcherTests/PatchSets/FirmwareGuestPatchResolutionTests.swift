// FirmwareGuestPatchResolutionTests.swift — The guest-half selection resolver.
//
// `FirmwareGuestPatchResolution` decides which patches the guest half of an
// install applies now: the boot chain as the plan recorded it, the guest half
// as the current selection resolves it. These tests pin that split and the
// membership of the guest-target set against the real bundled catalogue.

import FirmwarePatcher
import Foundation
import Testing
import VPhonePatchKit

@Suite("Guest patch resolution")
struct FirmwareGuestPatchResolutionTests {
    @Test
    func `Guest target identifiers include the guest patches and exclude the boot chain`() {
        let guest = FirmwareGuestPatchResolution.guestTargetIdentifiers

        // A dyld-cache patch, a guest Mach-O, a guest file, and a Preboot
        // device-tree patch are all guest-half.
        #expect(guest.contains("dyld-boot-lockdown_mode"))
        #expect(guest.contains("system-seputil-boot-gigalocker_uuid"))
        #expect(guest.contains("system-vphoned-boot-install"))
        #expect(guest.contains(FirmwareGuestSystemPatchSet.prebootHaptics))
        #expect(guest.contains(FirmwareGuestIdentityPatchSet.prebootDeviceTreeIdentity))

        // Every boot-chain patch is excluded: those are `fw patch`'s, not the
        // guest half's.
        for declaration in FirmwarePatchSetCatalog.allDeclarations where declaration.target.isBootChain {
            #expect(!guest.contains(declaration.identifier), "\(declaration.identifier) is boot-chain")
        }

        // And the set is exactly the non-boot-chain declarations.
        let expected = Set(
            FirmwarePatchSetCatalog.allDeclarations
                .filter { !$0.target.isBootChain }
                .map(\.identifier),
        )
        #expect(guest == expected)
    }

    @Test
    func `Effective enabled keeps boot chain from the plan and guest half from the selection`() {
        let guest = FirmwareGuestPatchResolution.guestTargetIdentifiers
        let bootChain = Set(
            FirmwarePatchSetCatalog.allDeclarations
                .filter(\.target.isBootChain)
                .map(\.identifier),
        )
        guard
            let boot = bootChain.first,
            let guestOn = guest.first,
            let guestOff = guest.dropFirst().first
        else {
            Issue.record("the bundled catalogue has too few patches to exercise the split")
            return
        }

        // The plan had a boot patch and one guest patch on; the selection now
        // has a *different* guest patch on and the old one off.
        let planEnabled: Set<String> = [boot, guestOn]
        let selectionEnabled: Set<String> = [guestOff]

        let effective = FirmwareGuestPatchResolution.effectiveEnabled(
            planEnabled: planEnabled,
            selectionEnabled: selectionEnabled,
        )

        #expect(effective.contains(boot), "the boot patch stays from the plan")
        #expect(effective.contains(guestOff), "a guest patch the selection turned on comes in")
        #expect(!effective.contains(guestOn), "a guest patch the selection turned off drops out")
    }

    @Test
    func `A boot-chain selection cannot add or drop guest patches`() {
        let guest = FirmwareGuestPatchResolution.guestTargetIdentifiers
        guard let guestID = guest.first else {
            Issue.record("no guest patches in the catalogue")
            return
        }
        // The selection resolves the guest patch off but names a boot patch the
        // plan never had: the boot side is the plan's alone, so nothing from the
        // selection's boot choices leaks in.
        let planEnabled: Set<String> = [guestID]
        let selectionEnabled: Set<String> = []
        let effective = FirmwareGuestPatchResolution.effectiveEnabled(
            planEnabled: planEnabled,
            selectionEnabled: selectionEnabled,
        )
        #expect(effective.isEmpty, "the guest patch drops and no boot patch is invented")
    }

    @Test
    func `Guest patches off is the guest set minus the selection`() {
        let guest = FirmwareGuestPatchResolution.guestTargetIdentifiers
        guard let on = guest.first else {
            Issue.record("no guest patches in the catalogue")
            return
        }
        let off = FirmwareGuestPatchResolution.guestPatchesOff(selectionEnabled: [on])
        #expect(!off.contains(on))
        #expect(off == guest.subtracting([on]))
    }
}
