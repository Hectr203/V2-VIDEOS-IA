// KernelCustomFirmwarePatchParavirtUserClients.swift — CFW kernel patch:
// narrow IOUserClient sandbox allowlist for the paravirtual device clients.
//
// The broad `patchIoucFailedSandbox` redirects the IOUserClient sandbox gate's
// deny block straight to its allow target, which opens *every* user client to a
// process outside an app sandbox. On a 26.x / 18.x base that is more than the
// problem needs: a daemon or a command-line tool is refused only the research
// board's paravirtual devices, because a 26.x sandbox has no allow rule for
// their classes. The symptoms (Lakr233/vphone-cli#22):
//   AppleParavirtDeviceUserClient                     -> Metal in a CLI/daemon
//   AppleVideoToolboxParavirtualizationUserClient     -> WebKit hardware decode
//   AppleVirtIONeuralEngineDeviceUserClient           -> Core ML / ANE
//   IOSurfaceAcceleratorParavirtClient                -> the paravirt scaler
//
// This patch allows only those, by class name, and leaves every other denial in
// place.
//
// Anchor (structural, no offsets). The deny block of the same gate ends by
// logging `IOUC %s failed sandbox in process %s`, whose first `%s` is the
// user-client class name. Right before the fail-log `adrp`, the class-name C
// string is already in x0:
//
//     <site>  ldr  x8, [sp, #imm]        ; displaced into the cave verbatim
//             stp  x0, x8, [sp]          ; x0 = class-name cstring, x8 = proc
//     <adrp>  adrp x0, <"IOUC %s failed sandbox …">
//             add  x0, x0, #…
//             bl   <log>
//             b    <join: return deny>
//
// So `site = adrp - 8`. The patch overwrites `site` with `b <cave>`; the cave
// reads the first eight bytes of the class name, allows (branches to the gate's
// NotPermitted allow target) when they match one of the four prefixes above, and
// otherwise runs the displaced `ldr` and falls back into the real deny path. The
// deny-entry and allow-target are found exactly as `patchIoucFailedSandbox` finds
// them.
//
// Cave instruction words are inline, each verified by clang/as assembly and a
// capstone round-trip (mirroring the fpfs and syscallmask caves); the two
// position-dependent `b` words are built by `ARM64Encoder`.

import Foundation
import VPhonePatchKit

extension KernelCustomFirmwarePatcher {
    /// First eight bytes of each allowed class name, as the four movz/movk
    /// half-words a 64-bit immediate needs (hw[k] = name[2k+1] << 8 | name[2k]).
    private static let allowedClassPrefixes: [[UInt16]] = [
        [0x7041, 0x6C70, 0x5065, 0x7261], // "ApplePar" — AppleParavirt*
        [0x7041, 0x6C70, 0x5665, 0x6469], // "AppleVid" — AppleVideoToolboxParavirt*
        [0x7041, 0x6C70, 0x5665, 0x7269], // "AppleVir" — AppleVirtIO*
        [0x4F49, 0x7553, 0x6672, 0x6361], // "IOSurfac" — IOSurfaceAcceleratorParavirtClient
    ]

    @discardableResult
    func patchParavirtUserClientsNarrow(
        patchID: String = FirmwarePatchSetCatalog.paravirtUserClientsPatch,
    ) -> Bool {
        log("\n[CFW]paravirt user clients: narrow IOUC sandbox allowlist")

        guard let failStrOff = buffer.findString("IOUC %s failed sandbox in process %s") else {
            log("  [-] IOUC failed-sandbox format string not found")
            return false
        }
        let refs = findStringRefs(failStrOff)
        guard !refs.isEmpty else {
            log("  [-] no xrefs for IOUC failed-sandbox format string")
            return false
        }

        for (adrpOff, _) in refs {
            guard let funcStart = findFunctionStart(adrpOff) else { continue }
            let funcEnd = findFuncEnd(funcStart, maxSize: 0x2000)

            var off = funcStart
            while off < adrpOff {
                defer { off += 4 }
                let insn = buffer.readU32(at: off)
                guard isCbnzW(insn), let denyEntry = cbTarget(insn, at: off) else { continue }
                guard denyEntry <= adrpOff, adrpOff < denyEntry + 0x60,
                      denyEntry > funcStart, denyEntry < funcEnd else { continue }

                var allowTarget = -1
                for back in stride(from: off - 4, through: off - 0x14, by: -4) where back > funcStart {
                    if let t = bCondEqTarget(buffer.readU32(at: back), at: back), t > funcStart, t < funcEnd {
                        allowTarget = t
                        break
                    }
                }
                guard allowTarget >= 0 else { continue }

                // The class-name cstring is live in x0 at `adrp - 8`, which is a
                // position-independent `ldr Xt, [sp, #imm]` (Xt is the proc name).
                let site = adrpOff - 8
                let denyContinue = adrpOff - 4
                guard site > denyEntry else { continue }
                let displaced = buffer.readU32(at: site)
                guard (displaced & 0xFFC0_0000) == 0xF940_0000, (displaced >> 5) & 0x1F == 31 else {
                    log("  [-] site is not ldr Xt,[sp,#imm]: 0x\(String(format: "%08X", displaced))")
                    continue
                }

                let wordCount = 2 + Self.allowedClassPrefixes.count * 6 + 2 + 1
                guard let caveOff = findCodeCave(size: wordCount * 4) else {
                    log("  [-] no code cave")
                    return false
                }
                guard let caveBytes = buildAllowlistCave(
                    caveOff: caveOff,
                    displacedWord: displaced,
                    denyContinue: denyContinue,
                    allowTarget: allowTarget,
                ) else { return false }
                guard let redirect = ARM64Encoder.encodeB(from: site, to: caveOff) else {
                    log("  [-] could not encode redirect branch")
                    return false
                }

                log("  [+] narrow allowlist fn=0x\(String(format: "%X", funcStart)), site=0x\(String(format: "%X", site)), cave=0x\(String(format: "%X", caveOff)), deny=0x\(String(format: "%X", denyEntry)), allow=0x\(String(format: "%X", allowTarget))")
                emit(
                    site,
                    redirect,
                    patchID: "\(patchID).redirect",
                    virtualAddress: fileOffsetToVA(site),
                    description: "ldr Xt,[sp,#imm] -> b cave [paravirt user-client allowlist]",
                )
                emit(
                    caveOff,
                    caveBytes,
                    patchID: "\(patchID).cave",
                    virtualAddress: fileOffsetToVA(caveOff),
                    description: "allow AppleParavirt/AppleVideoToolboxParavirt/AppleVirtIO/IOSurfaceAcceleratorParavirt, else deny",
                )
                return true
            }
        }

        log("  [-] narrow IOUC sandbox allowlist site not found")
        return false
    }

    /// Build the allowlist trampoline. Every fixed word is verified by clang/as
    /// assembly and a capstone round-trip; the two `b` words come from the
    /// keystone-backed `ARM64Encoder`.
    private func buildAllowlistCave(
        caveOff: Int,
        displacedWord: UInt32,
        denyContinue: Int,
        allowTarget: Int,
    ) -> Data? {
        /// movz x10,#hw0 ; movk x10,#hw{1,2,3},lsl #16·i  (x10 = 8-byte prefix)
        func buildConst(_ hw: [UInt16]) -> [UInt32] {
            var out: [UInt32] = [0xD280_0000 | (UInt32(hw[0]) << 5) | 10]
            for i in 1 ..< 4 {
                out.append(0xF280_0000 | (UInt32(i) << 21) | (UInt32(hw[i]) << 5) | 10)
            }
            return out
        }

        var w: [UInt32] = [
            0, // cbz x0, Ldeny          (filled below)
            0xF940_0009, // ldr x9, [x0]  ; x9 = class name[0:8]
        ]
        var beqSites: [Int] = []
        for hw in Self.allowedClassPrefixes {
            w += buildConst(hw) // 4 words -> x10
            w.append(0xEB0A_013F) // cmp x9, x10
            beqSites.append(w.count)
            w.append(0) // b.eq Lallow       (filled below)
        }
        let denyIdx = w.count
        w.append(displacedWord) // Ldeny: original ldr Xt,[sp,#imm]
        let denyBranchIdx = w.count
        w.append(0) // b <denyContinue>      (filled below)
        let allowIdx = w.count
        w.append(0) // Lallow: b <allowTarget> (filled below)

        // cbz x0, Ldeny  (rt = 0): imm19 = denyIdx (forward, in words)
        w[0] = 0xB400_0000 | ((UInt32(denyIdx) & 0x7FFFF) << 5)
        // b.eq Lallow for each class: imm19 = allowIdx - site
        for site in beqSites {
            let imm19 = UInt32(bitPattern: Int32(allowIdx - site)) & 0x7FFFF
            w[site] = 0x5400_0000 | (imm19 << 5) // cond EQ = 0
        }
        guard let denyB = ARM64Encoder.encodeB(from: caveOff + denyBranchIdx * 4, to: denyContinue),
              let allowB = ARM64Encoder.encodeB(from: caveOff + allowIdx * 4, to: allowTarget)
        else {
            log("  [-] could not encode cave branches")
            return nil
        }
        w[denyBranchIdx] = denyB.withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian
        w[allowIdx] = allowB.withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian

        var data = Data(capacity: w.count * 4)
        for word in w {
            withUnsafeBytes(of: word.littleEndian) { data.append(contentsOf: $0) }
        }
        return data
    }
}
