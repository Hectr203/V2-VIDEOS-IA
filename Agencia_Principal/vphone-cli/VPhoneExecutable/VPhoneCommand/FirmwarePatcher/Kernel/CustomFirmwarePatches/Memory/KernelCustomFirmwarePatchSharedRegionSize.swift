// KernelCustomFirmwarePatchSharedRegionSize.swift — CFW kernel patch: grow the
// arm64 shared region so an iOS 27 userland's dyld shared cache fits.
//
// The vphone600 26.4 kernel bakes SHARED_REGION_BASE_ARM64 ==
// SHARED_REGION_SIZE_ARM64 == 0x180000000 into `vm_shared_region_create`'s
// arm64 case (iOS 27 grew the arm64 default to 0x380000000 and raised the task
// map ceiling with it; this kernel's ceiling did not move, so Apple's value
// cannot simply be copied in). An iOS 27.0.1 iPhone18,x cache spans
// 0x185804000 — over the 6 GiB region even at slide 0, so
// `_shared_region_map_and_slide` ENOMEMs and launchd dies on "Library not
// loaded: /usr/lib/libSystem.B.dylib" (issue #596).
//
// The patch widens the region to 0x1C0000000 (7 GiB) and leaves the base
// alone. That value is the largest that keeps the region top (0x340000000)
// under this kernel's own task map ceilings — ARM64_MAX_OFFSET_DEVICE_SMALL
// 0x358000000 and LARGE 0x458000000, both compiled from the stock 6 GiB region
// — while still covering every iOS 27 cache read so far with its full 512 MiB
// slide (0x185804000 + 0x20000000 = 0x1A5804000).
//
// The block rewrite
// -----------------
// Because stock base and size are the same constant, the compiler issued one
// register for both and splatted it into the nesting pair:
//
//     mov  x22, #0x180000000     ; size  (ORR logical-immediate alias)
//     dup  v0.2d, x22
//     str  q0, [sp, #0x70]       ; nesting pair {base, size}
//     mov  x26, #0x180000000     ; base
//     b    <common>
//
// A size-only edit cannot work: `dup` would carry the old base into the pair,
// and the stock constant itself needs its own two-lane materialisation
// (0x180000000 is bits 31 and 32 — one movz cannot spell it, which is why the
// compiler chose the single-instruction ORR alias). The four instructions are
// rewritten as a unit, reusing the kernel's own base instruction verbatim, and
// the branch is left alone:
//
//     movz x22, #0xC000, lsl #16  ; size low lane
//     movk x22, #0x1, lsl #32     ; size high lane (0x1C0000000)
//     mov  x26, #0x180000000      ; base — the original ORR word, unchanged
//     stp  x26, x22, [sp, #0x70]  ; nesting pair {base, size}
//
// The base word is copied, not re-encoded: the matcher has already verified it
// materialises exactly 0x180000000 into the base register, and reproducing an
// ORR logical immediate would mean hand-rolling the encode table the patcher
// guardrails keep out (see `ARM64Inst.isORRImmW`'s comment for the same
// refusal on the decode side).
//
// Downstream — verified by disassembling both vphone600 variants against
// vm_shared_region.c — x26 feeds `base_address` and x22 `size` into
// `csm_setup_nested_address_space`, `pmap_set_shared_region` and both
// `vm_map_create_options` calls, and the stack pair becomes the nesting range,
// so one block covers every consumer. The size/base roles of the two
// registers are not distinguishable inside the window alone; the matcher takes
// i0 as size and i3 as base, the layout both shipped variants use (byte
// identical). Whether SPTM/TXM accept the wider nesting range is only
// provable by booting the guest.

import Foundation
import VPhonePatchKit

extension KernelCustomFirmwarePatcher {
    /// SHARED_REGION_BASE_ARM64 == SHARED_REGION_SIZE_ARM64 as baked into the
    /// vphone600 26.4 kernel's arm64 case. The matcher refuses anything else,
    /// which also makes a second run over a patched image a clean no-hit.
    private static let stockRegionBaseAndSize: UInt64 = 0x1_8000_0000

    /// `DUP Vd.2d, Xn` — general-register-to-vector duplicate, Q form. Rn (the
    /// source X register, bits 9:5) and Rd (the destination V register, 4:0)
    /// stay free; everything else in 0x4E080EC0 is fixed.
    private static let dupV2dMask: UInt32 = 0xFFFF_FC00
    private static let dupV2dValue: UInt32 = 0x4E08_0C00

    /// Widen the arm64 shared region. See the file header for the values and
    /// the reason the whole block is rewritten instead of one instruction.
    ///
    /// Anchor: the `dup Vd.2d, Xs` that splats the single shared-region
    /// constant into the nesting pair — the one instruction that only this
    /// block issues between a `mov #0x180000000` pair. The surrounding window
    /// is confirmed with Capstone, register by register, before anything is
    /// written.
    @discardableResult
    func patchSharedRegionSize() -> Bool {
        let stock = Self.stockRegionBaseAndSize
        let size = DyldSharedCacheMaxSlidePatcher.patchedKernelSharedRegionSize
        log("\n[CFW]vm_shared_region_create: arm64 region size \(hex(stock)) → \(hex(size))")

        guard let (textStart, textEnd) = kernTextRange else {
            log("  [-] __TEXT_EXEC not found")
            return false
        }

        let raw = buffer.original
        var hits: [(sizeReg: UInt32, baseReg: UInt32, pairDisp: Int32, blockOff: Int, baseInsn: Data)] = []

        var off = textStart
        while off + 20 <= min(textEnd, raw.count) {
            defer { off += 4 }
            // The dup sits one instruction after the size materialisation.
            let word = raw.loadLE(UInt32.self, at: off)
            guard word & Self.dupV2dMask == Self.dupV2dValue else { continue }

            guard let hit = matchRegionBlock(atDup: off, stockValue: stock) else { continue }
            hits.append(hit)
        }

        guard hits.count == 1 else {
            log("  [-] arm64 shared region block not found uniquely (\(hits.count) candidates)")
            return false
        }

        let hit = hits[0]
        let sizeLo = UInt16((size >> 16) & 0xFFFF)
        let sizeHi = UInt16((size >> 32) & 0xFFFF)
        // Both lanes must be live for the two-instruction materialisation the
        // rewrite uses; 0x1C0000000 has lane 1 = 0xC000 and lane 2 = 1.
        guard size & 0xFFFF == 0, sizeLo != 0, sizeHi != 0 else {
            log("  [-] patched size \(hex(size)) does not fit the movz+movk shape")
            return false
        }

        guard
            let lo = ARM64Encoder.encodeMovzX(rd: hit.sizeReg, imm16: sizeLo, shift: 16),
            let hi = ARM64Encoder.encodeMovkX(rd: hit.sizeReg, imm16: sizeHi, shift: 32),
            let pair = ARM64Encoder.encodeStpX(rt1: hit.baseReg, rt2: hit.sizeReg, rn: 31, offset: hit.pairDisp)
        else {
            log("  [-] replacement instructions unencodable (rd size=\(hit.sizeReg) base=\(hit.baseReg) disp=\(hit.pairDisp))")
            return false
        }

        var replacement = Data()
        replacement.append(lo)
        replacement.append(hi)
        replacement.append(hit.baseInsn)
        replacement.append(pair)

        let va = fileOffsetToVA(hit.blockOff)
        emit(
            hit.blockOff,
            replacement,
            patchID: "kernel-boot-shared_region_size",
            virtualAddress: va,
            description: "arm64 shared region size \(hex(stock)) → \(hex(size)) [vm_shared_region_create]",
        )
        return true
    }

    // MARK: - Private helpers

    /// Confirm the four-instruction window around the `dup` at `dupOff`:
    /// `mov #stock` into Xs, `dup Vd.2d, Xs`, `str Vd, [sp, #disp]`,
    /// `mov #stock` into Xb. Returns the two X-register numbers, the stack
    /// pair displacement, the file offset of the block start and the base
    /// instruction's own bytes (reused verbatim by the rewrite), or nil.
    private func matchRegionBlock(atDup dupOff: Int, stockValue: UInt64) -> (sizeReg: UInt32, baseReg: UInt32, pairDisp: Int32, blockOff: Int, baseInsn: Data)? {
        guard dupOff >= 4 else { return nil }
        let insns = disasm.disassemble(in: buffer.original, at: dupOff - 4, count: 4)
        guard insns.count == 4 else { return nil }

        // i0 — the size: `mov`/`movz`/`orr`-aliased `mov Xs, #stock`.
        guard let sizeReg = materialisedRegister(insns[0], value: stockValue) else { return nil }

        // i1 — `dup Vd.2d, Xs`, sourcing the register i0 wrote.
        guard insns[1].mnemonic == "dup",
              let dupOps = insns[1].detail?.operands, dupOps.count == 2,
              dupOps[0].type == .register, dupOps[1].type == .register,
              dupOps[1].reg == .x(Int(sizeReg))
        else { return nil }

        // i2 — `str Vd, [sp, #disp]`, storing the pair the dup filled. The dup
        // names the register `v0.2d` and the store `q0`; Capstone gives those
        // two spellings different register ids, so they are compared by lane.
        guard insns[2].mnemonic == "str",
              let strOps = insns[2].detail?.operands, strOps.count == 2,
              strOps[0].type == .register,
              let strLane = vectorLane(strOps[0].reg),
              let dupLane = vectorLane(dupOps[0].reg),
              strLane == dupLane,
              strOps[1].type == .memory,
              strOps[1].mem.base == .sp, strOps[1].mem.index == .invalid
        else { return nil }

        // i3 — the base: same constant, a different register.
        guard let baseReg = materialisedRegister(insns[3], value: stockValue),
              baseReg != sizeReg
        else { return nil }

        // i4 — an unconditional branch closes the block; it is preserved, so
        // only its shape is checked.
        guard jbDecodeBBranch(at: dupOff + 12) != nil else { return nil }

        let baseInsn = Data(buffer.original[(dupOff + 8) ..< (dupOff + 12)])
        return (sizeReg: sizeReg, baseReg: baseReg, pairDisp: strOps[1].mem.disp, blockOff: dupOff - 4, baseInsn: baseInsn)
    }

    /// The destination X-register of `mov Xd, #value` in any of its encodings
    /// (`movz` with a shift, or the ORR logical-immediate alias the 26.4
    /// compiler picked for 0x180000000), or nil when it is anything else.
    private func materialisedRegister(_ insn: ARM64Instruction, value: UInt64) -> UInt32? {
        let ops = insn.detail?.operands
        let wanted = Int64(bitPattern: value)

        // `mov Xd, #imm` / `movz Xd, #imm, lsl #…`: two operands.
        if ["mov", "movz"].contains(insn.mnemonic),
           let ops, ops.count == 2,
           ops[0].type == .register, ops[1].type == .immediate,
           ops[1].imm == wanted
        {
            return xRegisterNumber(ops[0].reg)
        }

        // `orr Xd, XZR, #bitmask` as Capstone spells it unaliased: the middle
        // operand must be xzr for this to be a plain materialisation.
        if insn.mnemonic == "orr",
           let ops, ops.count == 3,
           ops[0].type == .register, ops[1].type == .register, ops[1].reg == .xzr,
           ops[2].type == .immediate,
           ops[2].imm == wanted
        {
            return xRegisterNumber(ops[0].reg)
        }

        return nil
    }

    /// The number of an x0…x30 register, or nil for anything else.
    private func xRegisterNumber(_ reg: ARM64Register) -> UInt32? {
        for n in 0 ... 30 where ARM64Register.x(n) == reg {
            return UInt32(n)
        }
        return nil
    }

    /// The lane number of a vector register in any Capstone spelling — `v0`,
    /// `q0`, `d0` — or nil for anything else.
    private func vectorLane(_ reg: ARM64Register) -> Int? {
        guard let name = reg.name,
              let prefix = name.first, "vqdhsb".contains(prefix),
              let lane = Int(name.dropFirst())
        else { return nil }
        return lane
    }

    private func hex(_ v: UInt64) -> String {
        "0x\(String(v, radix: 16))"
    }
}
