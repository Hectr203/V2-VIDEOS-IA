// FirmwareExternalPatchSets.swift — The `.vphonepatchset` bundles one run loaded.
//
// A loaded set contributes patchers to the boot-chain components its manifest
// declares an enabled patch for, and nothing else. Two rules are worth stating
// where they are implemented:
//
//   * A set whose patches the plan all turned off is never asked for a patcher.
//     This is the same rule the bundled sets follow. A patcher built anyway would
//     emit records that no *enabled* declaration covers, and the gate applies an
//     undeclared record rather than dropping it (``VPhonePatchGate``), so the
//     patches would land after being switched off.
//
//   * External patchers run after the bundled patchers of the same component. The
//     order *among* external sets follows the resolved plan, so a set that
//     declared `After` another runs after it. Nothing lets an external set run
//     before a bundled one; a set that needs to undo a bundled patch blocks it in
//     the preset instead.

import Foundation
import VPhonePatchKit

final class FirmwareExternalPatchSets {
    private struct Loaded {
        let bundle: VPhonePatchSetBundle
        let principal: VPhonePatchSetPrincipal
    }

    private var loaded: [String: Loaded] = [:]

    var isEmpty: Bool {
        loaded.isEmpty
    }

    /// Map the set's executable and keep its principal for the rest of the run.
    ///
    /// The caller has already validated the manifest; this is the step that starts
    /// running the set's code.
    func add(_ bundle: VPhonePatchSetBundle) throws {
        loaded[bundle.manifest.identifier] = try Loaded(
            bundle: bundle,
            principal: bundle.loadPrincipal(),
        )
    }

    /// Factories for `component`, in the order the plan resolved the sets.
    func factories(
        for component: VPhoneFirmwareComponent,
        plan: VPhonePatchPlan,
        context: VPhonePatchSetContext,
    ) -> [(Data, Bool) throws -> any Patcher] {
        guard !loaded.isEmpty else { return [] }
        var factories: [(Data, Bool) throws -> any Patcher] = []
        for manifest in plan.patchSets {
            guard let entry = loaded[manifest.identifier],
                  entry.bundle.enabledComponents(in: plan).contains(component)
            else { continue }
            let principal = entry.principal
            factories.append { data, _ in
                try principal.makePatcher(for: component, data: data, context: context)
            }
        }
        return factories
    }
}
