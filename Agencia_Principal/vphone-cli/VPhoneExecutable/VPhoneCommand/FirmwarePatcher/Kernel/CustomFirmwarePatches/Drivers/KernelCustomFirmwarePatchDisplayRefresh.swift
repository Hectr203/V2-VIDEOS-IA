// KernelCustomFirmwarePatchDisplayRefresh.swift — CFW kernel patch: make the
// paravirtual display advertise a 120 Hz timing instead of the host's 60 Hz.
//
// Background: the host's VM service builds its one display mode with a constant
// `refreshRateInHz: 60.0`, and Virtualization has no setting for it.
// ParavirtualizedGraphics writes each mode into the display's shared state page
// as a 16-byte entry — u16 width, u16 height, u32 refresh in 16.16 Hz, flags —
// and that page is the only way the rate reaches the guest. Nothing on the host
// paces the guest: a present is consumed when it arrives, and its completion is
// what the guest's display driver sees as VBL.
//
// In the guest, `AppleParavirtDisplay::createDisplayAttributes`
// (AppleParavirtGPUIOGPUFamily) walks those entries and turns each into an IOAV
// timing element:
//
//     ldurh w1, [xN, #-8]     ; width
//     ldurh w2, [xN, #-6]     ; height
//     ldur  w3, [xN, #-4]     ; refresh, 16.16 Hz
//     mov   x0, xIndex
//     bl    <make timing element>
//
// `TimingElements` is where IOMobileFramebuffer and the render server learn the
// display's rate, so the load of `w3` becomes `movz w3, #120, lsl #16`.
//
// Anchor (no offsets): the `createDisplayAttributes` function-name cstring the
// driver passes to its logger, whose references all sit in that one function;
// inside it, the only place three consecutive loads off one base fill w1, w2 and
// w3 from displacements -8, -6 and -4 ahead of a call.

import Foundation
import VPhonePatchKit

extension KernelCustomFirmwarePatcher {
    /// The rate the guest display advertises once patched.
    private static let displayRefreshHz: UInt16 = 120

    @discardableResult
    func patchParavirtDisplayRefreshRate() -> Bool {
        log("\n[CFW]AppleParavirtDisplay timing element refresh: host 60 Hz -> \(Self.displayRefreshHz) Hz")

        guard let (ks, ke) = kernTextRange else {
            log("  [-] no kernel text range")
            return false
        }
        guard let nameOff = buffer.findString("createDisplayAttributes") else {
            log("  [-] createDisplayAttributes cstring not found")
            return false
        }
        let refs = findStringRefs(nameOff, in: (ks, ke))
        let starts = Set(refs.compactMap { findFunctionStart($0.adrpOff) })
        guard starts.count == 1, let funcStart = starts.first,
              let lastRef = refs.map(\.adrpOff).max()
        else {
            log("  [-] createDisplayAttributes not resolved to one function (found \(starts.count))")
            return false
        }

        var hits: [Int] = []
        var off = funcStart
        while off + 12 <= lastRef {
            defer { off += 4 }
            guard let width = loadFromBase(at: off, mnemonic: "ldurh", into: .w(1), disp: -8),
                  let height = loadFromBase(at: off + 4, mnemonic: "ldurh", into: .w(2), disp: -6),
                  let refresh = loadFromBase(at: off + 8, mnemonic: "ldur", into: .w(3), disp: -4),
                  width == height, height == refresh,
                  callFollows(off + 12)
            else { continue }
            hits.append(off + 8)
        }

        guard hits.count == 1, let loadOff = hits.first else {
            log("  [-] timing element refresh load not found uniquely (found \(hits.count))")
            return false
        }
        guard let movz = ARM64Encoder.encodeMovzW(rd: 3, imm16: Self.displayRefreshHz, shift: 16) else {
            log("  [-] could not encode the refresh constant")
            return false
        }

        emit(
            loadOff,
            movz,
            patchID: FirmwarePatchSetCatalog.proMotionPatch,
            virtualAddress: fileOffsetToVA(loadOff),
            description: "timing element refresh ldur w3,[mode,#-4] -> movz w3,#\(Self.displayRefreshHz),lsl #16 [16.16 Hz]",
        )
        return true
    }

    /// The base register when the instruction at `off` is `mnemonic reg, [base, #disp]`.
    private func loadFromBase(
        at off: Int,
        mnemonic: String,
        into reg: ARM64Register,
        disp: Int32,
    ) -> ARM64Register? {
        guard let insn = disasAt(off), insn.mnemonic == mnemonic,
              let ops = insn.detail?.operands, ops.count == 2,
              ops[0].type == .register, ops[0].reg == reg,
              ops[1].type == .memory, ops[1].mem.index == .invalid, ops[1].mem.disp == disp
        else { return nil }
        return ops[1].mem.base
    }

    /// True when a `bl` comes within the next three instructions, before any
    /// other control flow.
    private func callFollows(_ off: Int) -> Bool {
        for delta in stride(from: 0, to: 12, by: 4) {
            guard let insn = disasAt(off + delta) else { return false }
            if insn.mnemonic == "bl" {
                return true
            }
            if insn.isJump || insn.isReturn {
                return false
            }
        }
        return false
    }
}
