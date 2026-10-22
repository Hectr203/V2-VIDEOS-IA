// KernelExperimentalPatcher.swift — Experimental kernel patcher orchestrator.
//
// Runs after KernelPatcher + KernelCustomFirmwarePatcher for public CFW firmware.
// The internal historical `.exp` variant uses the same patcher.
//
// Current contents:
//   - patchHvVmmRename (Part A + Part B): rename the kern.hv_vmm_present
//     sysctl OID cstring AND mangle every kernel-internal caller. See
//     EXPPatches/KernelExperimentalPatchHvVmmRename.swift for the implementation.

import Foundation
import VPhonePatchKit

/// Experimental kernel patcher.
///
/// Inherits the CFW infrastructure (symbol table, ADRP/BL indices, branch
/// encoders, code-cave finder, string-anchored function finders, etc.) from
/// `KernelCustomFirmwarePatcherBase` so EXP-specific patches can use the same helpers
/// as CFW ones without duplicating them.
public final class KernelExperimentalPatcher: KernelCustomFirmwarePatcherBase, BufferedPatcher {
    public let component = "kernelcache_exp"

    public func findAll() throws -> [PatchRecord] {
        parseMachO()
        buildADRPIndex()
        buildBLIndex()
        buildSymbolTable()
        findPanic()

        // Former EXP patch, now part of the public CFW firmware pipeline.
        patchHvVmmRename()

        return patches
    }

    public func apply() throws -> Int {
        // `emit()` already wrote every record through to `buffer.data`.
        let records = try (patches.isEmpty ? findAll() : patches)
        return records.count
    }
}
