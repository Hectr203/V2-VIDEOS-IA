import CryptoKit
import Foundation
import VPhonePatchKit

/// GeneralSettingsUI's reviewed SoftwareUpdateListItemProvider Optional gate.
/// Locates the image by its type-name string, checks its UUID, follows resilient
/// Swift witnesses, and validates the cleanup path. No fixed address is used.
public enum DyldSharedCacheSettingsRowsPatcher {
    public struct Failure: Error, CustomStringConvertible { public let description: String }
    public struct Site: Sendable {
        public let address: UInt64
        public let before: Data
        public let replacement: Data
        public let alreadyPatched: Bool
    }

    private static let provider = "SoftwareUpdateListItemProvider"
    private static let installName =
        "/System/Library/PrivateFrameworks/Settings/GeneralSettingsUI.framework/GeneralSettingsUI"
    private static let uuid = Data([
        0xF8, 0xC2, 0x94, 0xB7, 0x2C, 0xFB, 0x31, 0x2F, 0xA2, 0xAB, 0xF8, 0x72, 0x3F, 0x2B, 0x91, 0x07,
    ])
    public static func discover(in chunks: DyldSharedCacheChunkSet) throws -> Site {
        func fail(_ text: String) -> Failure {
            Failure(description: text)
        }
        func word(_ va: UInt64) throws -> UInt32 {
            try chunks.readAtVMA(va, length: 4).loadLE(UInt32.self, at: 0)
        }
        func relative(_ va: UInt64) throws -> UInt64 {
            let result = try Int64(va) + Int64(Int32(bitPattern: word(va)))
            guard result > 0 else { throw fail("invalid relative address") }
            return UInt64(result)
        }
        var headers = Set<UInt64>()
        for string in try chunks.findStringVMAs(Data((provider + "\0").utf8)) {
            if let h = try chunks.findMachOHeaderBefore(string),
               chunks.readInstallName(atHeaderVMA: h) == installName
            {
                headers.insert(h)
            }
        }
        guard headers.count == 1, let header = headers.first else {
            throw fail("GeneralSettingsUI missing or ambiguous")
        }
        let head = try chunks.readAtVMA(header, length: 65536, allowShort: true)
        guard head.count >= 32 else { throw fail("short header") }
        let commandEnd = 32 + Int(head.loadLE(UInt32.self, at: 20))
        let commandCount = Int(head.loadLE(UInt32.self, at: 16))
        guard commandEnd <= head.count, commandCount <= 256 else { throw fail("invalid load commands") }
        var p = 32
        var proto: (UInt64, Int)?
        var link: (UInt64, UInt64, UInt64)?
        var startsInfo: (UInt64, Int)?
        var imageUUID: Data?
        for _ in 0 ..< commandCount {
            guard p + 8 <= commandEnd else { throw fail("short command") }
            let cmd = head.loadLE(UInt32.self, at: p)
            let size = Int(head.loadLE(UInt32.self, at: p + 4))
            guard size >= 8, size <= commandEnd - p else { throw fail("invalid command size") }
            if cmd == 0x1B {
                guard size >= 24 else { throw fail("short UUID") }
                imageUUID = head.subdata(in: p + 8 ..< p + 24)
            }
            if cmd == 0x26 {
                guard size >= 16 else { throw fail("short starts") }
                startsInfo = (
                    UInt64(head.loadLE(UInt32.self, at: p + 8)), Int(head.loadLE(UInt32.self, at: p + 12)),
                )
            }
            if cmd == 0x19 {
                guard size >= 72 else { throw fail("short segment") }
                let name = String(decoding: head[p + 8 ..< p + 24].prefix(while: { $0 != 0 }), as: UTF8.self)
                if name == "__LINKEDIT" {
                    link = (
                        head.loadLE(UInt64.self, at: p + 24), head.loadLE(UInt64.self, at: p + 40),
                        head.loadLE(UInt64.self, at: p + 48),
                    )
                }
                let count = Int(head.loadLE(UInt32.self, at: p + 64))
                guard count <= (size - 72) / 80 else { throw fail("bad sections") }
                for i in 0 ..< count {
                    let s = p + 72 + i * 80
                    let name = String(decoding: head[s ..< s + 16].prefix(while: { $0 != 0 }), as: UTF8.self)
                    if name == "__swift5_proto" {
                        proto = (
                            head.loadLE(UInt64.self, at: s + 32), Int(head.loadLE(UInt64.self, at: s + 40)),
                        )
                    }
                }
            }
            p += size
        }
        guard imageUUID == uuid else { throw fail("unreviewed GeneralSettingsUI UUID") }
        guard let (pv, ps) = proto, ps > 0, ps < 1_048_576, ps % 4 == 0, let (lv, lf, ls) = link,
              let (fo, fs) = startsInfo, fo >= lf, fo - lf <= ls, fs > 0, fs <= 1_048_576,
              UInt64(fs) <= ls - (fo - lf)
        else { throw fail("missing or invalid discovery metadata") }
        let encoded = try chunks.readAtVMA(lv + fo - lf, length: fs)
        var starts = Set<UInt64>()
        var cursor = 0
        var address = header
        while cursor < encoded.count {
            var value: UInt64 = 0
            var shift = 0
            var byte: UInt8
            repeat {
                guard cursor < encoded.count, shift < 63 else { throw fail("invalid function starts") }
                byte = encoded[cursor]
                cursor += 1
                value |= UInt64(byte & 127) << shift
                shift += 7
            } while byte & 128 != 0
            if value == 0 {
                break
            }
            guard address <= UInt64.max - value else { throw fail("start overflow") }
            address += value
            starts.insert(address)
        }
        let decoder = ARM64Disassembler()
        func body(_ start: UInt64) throws -> [ARM64Instruction] {
            guard starts.contains(start), let end = starts.filter({ $0 > start }).min(),
                  end - start < 20000
            else { return [] }
            return try decoder.disassemble(chunks.readAtVMA(start, length: Int(end - start)), at: start)
        }
        var sites: [UInt64: Site] = [:]
        for i in stride(from: 0, to: ps, by: 4) {
            let c = try relative(pv + UInt64(i))
            let flags = try word(c + 12)
            guard (flags >> 3) & 7 == 0, flags & 0xFF00 == 0, flags & 0x10000 != 0 else { continue }
            let type = try relative(c + 4)
            let nameVA = try relative(type + 8)
            let name = try chunks.readAtVMA(nameVA, length: 128, allowShort: true)
            guard String(decoding: name.prefix(while: { $0 != 0 }), as: UTF8.self) == provider else {
                continue
            }
            let count = try word(c + 16)
            guard count <= 64 else { throw fail("invalid witness count") }
            for slot in 0 ..< count {
                let witness = try relative(c + UInt64(24 + slot * 8))
                for call in try body(witness) where call.mnemonic == "bl" {
                    guard let op = call.detail?.operands.first, op.type == .immediate, op.imm > 0 else {
                        continue
                    }
                    let instructions = try body(UInt64(op.imm))
                    for k in 2 ..< max(2, instructions.count) {
                        let branch = instructions[k]
                        let cmp = instructions[k - 1]
                        guard instructions[k - 2].mnemonic == "blraa", cmp.mnemonic == "cmp",
                              let operands = cmp.detail?.operands, operands.count == 2, operands[0].reg == .w(0),
                              operands[1].type == .immediate, operands[1].imm == 1
                        else { continue }
                        let patched =
                            branch.mnemonic == "b"
                                && branch.detail?.operands.first?.imm == Int64(branch.address + 4)
                        guard branch.mnemonic == "b.ne" || patched else { continue }
                        let tail = Array(instructions.dropFirst(k + 1).prefix(40))
                        guard let merge = tail.firstIndex(where: { $0.mnemonic == "b" || $0.isReturn }),
                              tail[merge].mnemonic == "b",
                              tail.prefix(merge).contains(where: { $0.mnemonic == "bl" })
                        else { continue }
                        let normal = tail[merge].address + 4
                        guard patched || branch.detail?.operands.first?.imm == Int64(normal) else { continue }
                        guard
                            let replacement = ARM64Encoder.encodeB(
                                from: Int(branch.address), to: Int(branch.address + 4),
                            )
                        else { throw fail("branch encoding failed") }
                        let before = try chunks.readAtVMA(branch.address, length: 4)
                        sites[branch.address] = Site(
                            address: branch.address, before: before, replacement: replacement,
                            alreadyPatched: patched,
                        )
                    }
                }
            }
        }
        guard sites.count == 1, let site = sites.values.first else {
            throw fail("missing or ambiguous Optional cleanup branch")
        }
        return site
    }

    public static func patch(in chunks: DyldSharedCacheChunkSet, dryRun: Bool = false) throws -> Site {
        let site = try discover(in: chunks)
        guard !dryRun else { return site }
        // Validate the signature before any write; no silent skipped attestation.
        let span = DyldSharedCacheWriteSpan(vma: site.address, length: 4)
        let preview = try DyldSharedCacheCodeSignature.reattest(
            in: chunks, modifiedSpans: [span], dryRun: true, log: nil,
        )
        guard preview.isFullyAttested, preview.pagesAttested == 1 else {
            throw Failure(description: "cannot attest target page")
        }
        if !site.alreadyPatched {
            try chunks.write(at: site.address, site.replacement)
        }
        let result = try DyldSharedCacheCodeSignature.reattest(in: chunks, modifiedSpans: [span])
        guard result.isFullyAttested, result.pagesAttested == 1 else {
            throw Failure(description: "target page not attested")
        }
        return site
    }
}
