import CryptoKit
import Foundation
import VPhonePatchKit

/// Reviewed iOS 27 / 24A435 Settings root-row transformation.
/// Discovery uses Swift witnesses and native Mach-O import tables, never fixed addresses.
/// Input is deliberately restricted to the reviewed original; apply to the installer's
/// pristine backup. Signing, deployment, patch selection and receipts belong to the caller.
public enum CustomFirmwareSettingsRows {
    public struct Edit: Sendable {
        public let identifier: String
        public let address: UInt64
        public let fileOffset: Int
        public let before: Data
        public let after: Data
    }

    public struct Result: Sendable {
        public let data: Data
        public let edits: [Edit]
    }

    private static let rootProviders = [
        "PrimaryAppleAccountListItemProvider", "iCloudListItemProvider",
        "WalletAndApplePayOrPaymentAndContactlessListItemProvider",
    ]
    public static func patchPreferences(_ original: Data) throws -> Result {
        let digest = SHA256.hash(data: original).map { String(format: "%02x", $0) }.joined()
        guard digest == "e59851f14f29409590a6de76ca2fe9b9912341aee526a278692ef0d7a86ee2f3" else {
            throw InvalidImage(
                description: "unreviewed Preferences input; use the pristine reviewed backup",
            )
        }
        let image = try Image(original)
        var edits = try providerEdits(image)
        edits += try gameCenterEdits(image)
        edits.sort { $0.fileOffset < $1.fileOffset }
        guard edits.count == 5 else {
            throw InvalidImage(description: "expected five instructions for four root rows")
        }
        var output = original
        var lastEnd = 0
        for edit in edits {
            guard edit.fileOffset >= lastEnd, edit.after.count == 4, edit.before.count == 4 else {
                throw InvalidImage(description: "overlapping or malformed edits")
            }
            try image.check(edit.fileOffset, 4)
            guard output.subdata(in: edit.fileOffset ..< edit.fileOffset + 4) == edit.before else {
                throw InvalidImage(description: "preimage changed")
            }
            output.replaceSubrange(edit.fileOffset ..< edit.fileOffset + 4, with: edit.after)
            lastEnd = edit.fileOffset + 4
        }
        return Result(data: output, edits: edits)
    }

    private static func makeEdit(_ image: Image, _ name: String, _ va: UInt64, _ bytes: Data) throws
        -> Edit
    {
        let offset = try image.offset(va)
        try image.check(offset, 4)
        return Edit(
            identifier: name, address: va, fileOffset: offset,
            before: image.data.subdata(in: offset ..< offset + 4), after: bytes,
        )
    }

    private struct InvalidImage: Error, CustomStringConvertible { let description: String }
    private struct Image {
        let data: Data
        struct Segment {
            let va: UInt64
            let size: UInt64
            let file: Int
        }

        struct Section {
            let name: String
            let va: UInt64
            let size: Int
            let file: Int
        }

        var segments: [Segment] = []
        var sections: [Section] = []
        var starts: Set<UInt64> = []
        func check(_ p: Int, _ n: Int) throws {
            guard p >= 0, n >= 0, p <= data.count, n <= data.count - p else {
                throw InvalidImage(description: "out of bounds \(p), \(n)")
            }
        }

        func word(_ p: Int) throws -> UInt32 {
            try check(p, 4)
            return data.withUnsafeBytes {
                UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: p, as: UInt32.self))
            }
        }

        func quad(_ p: Int) throws -> UInt64 {
            try check(p, 8)
            return data.withUnsafeBytes {
                UInt64(littleEndian: $0.loadUnaligned(fromByteOffset: p, as: UInt64.self))
            }
        }

        func name(_ p: Int, _ max: Int = 512) throws -> String {
            try check(p, 1)
            let end = min(data.count, p + max)
            guard let z = data[p ..< end].firstIndex(of: 0) else {
                throw InvalidImage(description: "unterminated string")
            }
            return String(decoding: data[p ..< z], as: UTF8.self)
        }

        func offset(_ va: UInt64) throws -> Int {
            guard let s = segments.first(where: { va >= $0.va && va - $0.va < $0.size }) else {
                throw InvalidImage(description: "unmapped VA")
            }
            let p = s.file + Int(va - s.va)
            try check(p, 1)
            return p
        }

        func relative(_ va: UInt64) throws -> UInt64 {
            let delta = try Int64(Int32(bitPattern: word(offset(va))))
            let value = Int64(va) + delta
            guard value >= 0 else { throw InvalidImage(description: "negative address") }
            return UInt64(value)
        }

        init(_ data: Data) throws {
            self.data = data
            guard try word(0) == 0xFEED_FACF, try word(4) == 0x0100_000C else {
                throw InvalidImage(description: "expected ARM64 Mach-O")
            }
            let end = try 32 + Int(word(20))
            try check(32, end - 32)
            var p = 32
            var fs: (Int, Int)?
            for _ in try 0 ..< word(16) {
                let cmd = try word(p)
                let n = try Int(word(p + 4))
                guard n >= 8, p + n <= end else { throw InvalidImage(description: "bad load command") }
                if cmd == 0x19 {
                    guard n >= 72 else { throw InvalidImage(description: "short segment") }
                    let count = try Int(word(p + 64))
                    guard count <= (n - 72) / 80 else { throw InvalidImage(description: "short sections") }
                    let file = try Int(quad(p + 40))
                    let size = try quad(p + 48)
                    try check(file, Int(size))
                    try segments.append(Segment(va: quad(p + 24), size: size, file: file))
                    for i in 0 ..< count {
                        let s = p + 72 + i * 80
                        try sections.append(
                            Section(
                                name: String(decoding: data[s ..< s + 16].prefix(while: { $0 != 0 }), as: UTF8.self),
                                va: quad(s + 32), size: Int(quad(s + 40)), file: Int(word(s + 48)),
                            ),
                        )
                    }
                }
                if cmd == 0x26 {
                    guard n >= 16 else { throw InvalidImage(description: "short function starts") }
                    fs = try (Int(word(p + 8)), Int(word(p + 12)))
                }
                p += n
            }
            if let (at, size) = fs, let text = sections.first(where: { $0.name == "__text" }),
               let base = segments.first(where: { text.va >= $0.va && text.va - $0.va < $0.size })?.va
            {
                try check(at, size)
                var cur = at
                var va = base
                while cur < at + size {
                    var value: UInt64 = 0
                    var shift = 0
                    var byte: UInt8
                    repeat {
                        guard cur < at + size, shift < 63 else { throw InvalidImage(description: "bad ULEB") }
                        byte = data[cur]
                        cur += 1
                        value |= UInt64(byte & 127) << shift
                        shift += 7
                    } while byte & 128 != 0
                    if value == 0 {
                        break
                    }
                    va += value
                    starts.insert(va)
                }
            }
        }
    }

    private static func instructions(_ image: Image, _ va: UInt64) throws -> [ARM64Instruction] {
        let decoder = ARM64Disassembler()
        let end = image.starts.filter { $0 > va }.min() ?? va
        guard end > va, end - va < 20000 else { return [] }
        let off = try image.offset(va)
        try image.check(off, Int(end - va))
        return decoder.disassemble(Data(image.data[off ..< off + Int(end - va)]), at: va)
    }

    private static func providerEdits(_ image: Image) throws -> [Edit] {
        let decoder = ARM64Disassembler()
        guard let proto = image.sections.first(where: { $0.name == "__swift5_proto" }) else {
            throw InvalidImage(description: "missing conformance section")
        }
        var sites: [String: [(UInt64, Data)]] = [:]
        let wanted = Set(rootProviders)
        for i in stride(from: 0, to: proto.size, by: 4) {
            let c = try image.relative(proto.va + UInt64(i))
            let cp = try image.offset(c)
            let flags = try image.word(cp + 12)
            guard (flags >> 3) & 7 == 0, flags & 0xFF00 == 0, flags & 0x10000 != 0 else { continue }
            let t = try image.relative(c + 4)
            let name = try image.name(image.offset(image.relative(t + 8)))
            guard wanted.contains(name) else { continue }
            let n = try Int(image.word(cp + 16))
            guard n <= 64 else { throw InvalidImage(description: "witness overflow") }
            for slot in 0 ..< n {
                let impl = try image.relative(c + UInt64(24 + slot * 8))
                guard image.starts.contains(impl) else { continue }
                let wrapper = try instructions(image, impl)
                for call in wrapper where call.mnemonic == "bl" {
                    guard let op = call.detail?.operands.first, op.type == .immediate, op.imm > 0,
                          image.starts.contains(UInt64(op.imm))
                    else { continue }
                    let body = try instructions(image, UInt64(op.imm))
                    for k in 1 ..< body.count {
                        let prev = body[k - 1]
                        let branch = body[k]
                        guard prev.mnemonic == "cmp", let ops = prev.detail?.operands, ops.count == 2,
                              ops[0].type == .register, ops[0].reg == .w(0), ops[1].type == .immediate,
                              ops[1].imm == 1, branch.mnemonic == "b.ne"
                        else { continue }
                        guard k >= 2, body[k - 2].mnemonic == "blraa",
                              let dest = branch.detail?.operands.first, dest.type == .immediate,
                              dest.imm > Int64(branch.address),
                              let end = body.firstIndex(where: { $0.address == UInt64(dest.imm) }),
                              end > k, end - k <= 40
                        else { continue }
                        let fallthroughBlock = Array(
                            body[(k + 1) ..< end].prefix(while: { $0.mnemonic != "b" && !$0.isReturn }),
                        )
                        guard fallthroughBlock.contains(where: { $0.mnemonic == "bl" }),
                              k + 1 + fallthroughBlock.count < end,
                              body[k + 1 + fallthroughBlock.count].mnemonic == "b"
                        else {
                            continue
                        }
                        guard
                            let replacement = ARM64Encoder.encodeB(
                                from: Int(branch.address), to: Int(branch.address + 4),
                            ),
                            let decoded = decoder.disassembleOne(replacement, at: branch.address),
                            decoded.mnemonic == "b",
                            decoded.detail?.operands.first?.imm == Int64(branch.address + 4)
                        else { throw InvalidImage(description: "encoder round trip failed") }
                        sites[name, default: []].append((branch.address, replacement))
                    }
                }
            }
        }
        for (name, matches) in sites.sorted(by: { $0.key < $1.key }) {
            guard matches.count == 1 else {
                throw InvalidImage(description: "ambiguous sites for \(name)")
            }
        }
        var edits: [Edit] = []
        for name in rootProviders {
            guard let candidates = sites[name], candidates.count == 1 else {
                throw InvalidImage(description: "missing or ambiguous provider \(name)")
            }
            try edits.append(makeEdit(image, name, candidates[0].0, candidates[0].1))
        }
        return edits
    }

    private static func gameCenterEdits(_ image: Image) throws -> [Edit] {
        // Resolve the named import through LC_SYMTAB, LC_DYSYMTAB and pointer sections.
        // No exported r2 JSON or absolute GOT address is part of the patch input.
        var sym: (Int, Int, Int, Int)?
        var indirect: (Int, Int)?
        var pointerSections: [(UInt64, Int, Int)] = []
        var command = 32
        for _ in try 0 ..< (image.word(16)) {
            let kind = try image.word(command)
            let size = try Int(image.word(command + 4))
            if kind == 2 {
                try image.check(command, 24)
                sym = try (
                    Int(image.word(command + 8)), Int(image.word(command + 12)),
                    Int(image.word(command + 16)), Int(image.word(command + 20)),
                )
            }
            if kind == 0xB {
                try image.check(command, 80)
                indirect = try (Int(image.word(command + 56)), Int(image.word(command + 60)))
            }
            if kind == 0x19 {
                let count = try Int(image.word(command + 64))
                for i in 0 ..< count {
                    let section = command + 72 + i * 80
                    let flags = try image.word(section + 64) & 0xFF
                    if flags == 6 || flags == 7 {
                        try pointerSections.append(
                            (
                                image.quad(section + 32), Int(image.quad(section + 40)) / 8,
                                Int(image.word(section + 68)),
                            ),
                        )
                    }
                }
            }
            command += size
        }
        guard let (symbols, symbolCount, strings, stringSize) = sym,
              let (indirectOffset, indirectCount) = indirect
        else { throw InvalidImage(description: "missing symbol tables\n") }
        try image.check(symbols, symbolCount * 16)
        try image.check(strings, stringSize)
        try image.check(indirectOffset, indirectCount * 4)
        var targets: [UInt64] = []
        for (base, count, first) in pointerSections {
            guard first <= indirectCount, count <= indirectCount - first else {
                throw InvalidImage(description: "indirect section out of bounds")
            }
            for slot in 0 ..< count {
                let symbol = try image.word(indirectOffset + (first + slot) * 4)
                if symbol & 0xC000_0000 != 0 {
                    continue
                }
                guard symbol < symbolCount else { throw InvalidImage(description: "bad symbol index") }
                let nameOffset = try Int(image.word(symbols + Int(symbol) * 16))
                guard nameOffset < stringSize else {
                    throw InvalidImage(description: "bad symbol name offset")
                }
                if try image.name(strings + nameOffset, stringSize - nameOffset)
                    == "_MCFeatureGameCenterAllowed"
                {
                    targets.append(base + UInt64(slot * 8))
                }
            }
        }
        guard targets.count == 1 else { throw InvalidImage(description: "ambiguous named import\n") }
        let got = targets[0]
        guard let text = image.sections.first(where: { $0.name == "__text" }) else {
            throw InvalidImage(description: "missing text")
        }
        let decoder = ARM64Disassembler()
        let code = decoder.disassemble(Data(image.data[text.file ..< text.file + text.size]), at: text.va)
        var candidates: [(Int, Int, UInt32)] = []
        for i in 8 ..< code.count {
            let a = code[i - 1]
            let l = code[i]
            guard a.mnemonic == "adrp", l.mnemonic == "ldr", let ao = a.detail?.operands,
                  let lo = l.detail?.operands, ao.count == 2, lo.count == 2, ao[1].type == .immediate,
                  lo[1].type == .memory, ao[0].reg == lo[1].mem.base,
                  UInt64(ao[1].imm) + UInt64(lo[1].mem.disp) == got
            else { continue }
            let tag = code[i - 4]
            let call = code[i - 3]
            let store = code[i - 7]
            let arg0 = code[i - 6]
            guard tag.mnemonic == "mov", let t = tag.detail?.operands, t.count == 2, t[0].reg == .w(2),
                  t[1].imm == 8, call.mnemonic == "bl", store.mnemonic == "strb",
                  let so = store.detail?.operands, so.count == 2, so[1].type == .memory, so[1].mem.disp == 0,
                  arg0.mnemonic == "mov", let args = arg0.detail?.operands, args.count == 2,
                  args[0].reg == .x(0), args[1].reg == so[1].mem.base
            else { continue }
            guard let rn = (0 ..< 31).first(where: { so[1].mem.base == .x($0) }) else { continue }
            candidates.append((i - 7, i - 4, UInt32(rn)))
        }
        guard candidates.count == 1 else {
            throw InvalidImage(description: "expected one construction block, got \(candidates.count)")
        }
        let (s, t, rn) = candidates[0]
        let changes = [
            (code[s], ARM64Encoder.encodeStrXUnsignedOffset(rt: 31, rn: rn, offset: 0)!),
            (code[t], ARM64Encoder.encodeMovzW(rd: 2, imm16: 2)!),
        ]
        return try changes.map { try makeEdit(image, "GameCenter", $0.0.address, $0.1) }
    }
}
