import CryptoKit
import Foundation

struct InvalidImage: Error, CustomStringConvertible { let description: String }
struct Image {
    let data: Data
    struct Segment { let va: UInt64; let size: UInt64; let file: Int }
    struct Section { let name: String; let va: UInt64; let size: Int; let file: Int }
    var segments: [Segment] = []
    var sections: [Section] = []
    var starts: Set<UInt64> = []
    func check(_ p: Int, _ n: Int) throws {
        guard p >= 0, n >= 0, p <= data.count, n <= data.count - p else { throw InvalidImage(description: "out of bounds \(p), \(n)") }
    }

    func word(_ p: Int) throws -> UInt32 {
        try check(p, 4); return data.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: p, as: UInt32.self)) }
    }

    func quad(_ p: Int) throws -> UInt64 {
        try check(p, 8); return data.withUnsafeBytes { UInt64(littleEndian: $0.loadUnaligned(fromByteOffset: p, as: UInt64.self)) }
    }

    func name(_ p: Int, _ max: Int = 512) throws -> String {
        try check(p, 1); let end = min(data.count, p + max); guard let z = data[p ..< end].firstIndex(of: 0) else { throw InvalidImage(description: "unterminated string") }; return String(decoding: data[p ..< z], as: UTF8.self)
    }

    func offset(_ va: UInt64) throws -> Int {
        guard let s = segments.first(where: { va >= $0.va && va - $0.va < $0.size }) else { throw InvalidImage(description: "unmapped VA") }; let p = s.file + Int(va - s.va); try check(p, 1); return p
    }

    func relative(_ va: UInt64) throws -> UInt64 {
        let delta = try Int64(Int32(bitPattern: word(offset(va)))); let value = Int64(va) + delta; guard value >= 0 else { throw InvalidImage(description: "negative address") }; return UInt64(value)
    }

    init(_ data: Data) throws {
        self.data = data
        guard try word(0) == 0xFEED_FACF, try word(4) == 0x0100_000C else { throw InvalidImage(description: "expected ARM64 Mach-O") }
        let end = try 32 + Int(word(20)); try check(32, end - 32)
        var p = 32; var fs: (Int, Int)?
        for _ in try 0 ..< word(16) {
            let cmd = try word(p), n = try Int(word(p + 4)); guard n >= 8, p + n <= end else { throw InvalidImage(description: "bad load command") }
            if cmd == 0x19 {
                guard n >= 72 else { throw InvalidImage(description: "short segment") }
                let count = try Int(word(p + 64)); guard count <= (n - 72) / 80 else { throw InvalidImage(description: "short sections") }
                let file = try Int(quad(p + 40)), size = try quad(p + 48); try check(file, Int(size))
                try segments.append(Segment(va: quad(p + 24), size: size, file: file))
                for i in 0 ..< count {
                    let s = p + 72 + i * 80; try sections.append(Section(name: String(decoding: data[s ..< s + 16].prefix(while: { $0 != 0 }), as: UTF8.self), va: quad(s + 32), size: Int(quad(s + 40)), file: Int(word(s + 48))))
                }
            }
            if cmd == 0x26 {
                guard n >= 16 else { throw InvalidImage(description: "short function starts") }; fs = try (Int(word(p + 8)), Int(word(p + 12)))
            }
            p += n
        }
        if let (at, size) = fs, let text = sections.first(where: { $0.name == "__text" }), let base = segments.first(where: { text.va >= $0.va && text.va - $0.va < $0.size })?.va {
            try check(at, size); var cur = at; var va = base
            while cur < at + size {
                var value: UInt64 = 0; var shift = 0; var byte: UInt8
                repeat {
                    guard cur < at + size, shift < 63 else { throw InvalidImage(description: "bad ULEB") }; byte = data[cur]; cur += 1; value |= UInt64(byte & 127) << shift; shift += 7
                } while byte & 128 != 0
                if value == 0 {
                    break
                }; va += value; starts.insert(va)
            }
        }
    }

    func resolve() throws {
        guard let proto = sections.first(where: { $0.name == "__swift5_proto" }) else { throw InvalidImage(description: "no conformances") }
        for i in stride(from: 0, to: proto.size, by: 4) {
            let c = try relative(proto.va + UInt64(i)); let cp = try offset(c); let flags = try word(cp + 12)
            // Only non-generic direct nominal references without conditional trailing records.
            guard (flags >> 3) & 7 == 0, flags & 0xFF00 == 0, flags & 0x10000 != 0 else { continue }
            let type = try relative(c + 4), tp = try offset(type); guard try word(tp) & 0x80 == 0 else { continue }
            let typeName = try name(offset(relative(type + 8))); guard typeName.contains("Provider") else { continue }
            let count = try Int(word(cp + 16)); guard count <= 64 else { throw InvalidImage(description: "invalid witness count") }
            try check(cp + 20, count * 8)
            var functions: [String] = []
            for slot in 0 ..< count {
                let impl = try relative(c + UInt64(24 + slot * 8)); if starts.contains(impl) {
                    functions.append(String(format: "%d:0x%llx", slot, impl))
                }
            }
            print(typeName, functions.joined(separator: " "))
        }
    }
}

import VPhonePatchKit

let decoder = ARM64Disassembler()
func instructions(_ image: Image, _ va: UInt64) throws -> [ARM64Instruction] {
    let end = image.starts.filter { $0 > va }.min() ?? va
    guard end > va, end - va < 20000 else { return [] }
    let off = try image.offset(va); try image.check(off, Int(end - va))
    return decoder.disassemble(Data(image.data[off ..< off + Int(end - va)]), at: va)
}

do {
    guard CommandLine.arguments.count > 1 else { throw InvalidImage(description: "input path required") }
    let path = CommandLine.arguments[1]
    let input = try Data(contentsOf: URL(fileURLWithPath: path))
    let inputHash = SHA256.hash(data: input).map { String(format: "%02x", $0) }.joined()
    let reviewedInputs: Set = ["e59851f14f29409590a6de76ca2fe9b9912341aee526a278692ef0d7a86ee2f3", "e43fa27956007aef6180570b242e3b08bb2030841121d13ac8671ec9f8480dd1"]
    guard reviewedInputs.contains(inputHash) else { throw InvalidImage(description: "unreviewed input hash; parsing and output refused") }
    let image = try Image(input)
    guard let proto = image.sections.first(where: { $0.name == "__swift5_proto" }) else { throw InvalidImage(description: "missing conformance section") }
    var sites: [String: [(UInt64, Data)]] = [:]
    let wanted: Set = ["PrimaryAppleAccountListItemProvider", "iCloudListItemProvider", "WalletAndApplePayOrPaymentAndContactlessListItemProvider", "SoftwareUpdateListItemProvider"]
    for i in stride(from: 0, to: proto.size, by: 4) {
        let c = try image.relative(proto.va + UInt64(i)); let cp = try image.offset(c); let flags = try image.word(cp + 12)
        guard (flags >> 3) & 7 == 0, flags & 0xFF00 == 0, flags & 0x10000 != 0 else { continue }
        let t = try image.relative(c + 4); let name = try image.name(image.offset(image.relative(t + 8))); guard wanted.contains(name) else { continue }
        let n = try Int(image.word(cp + 16)); guard n <= 64 else { throw InvalidImage(description: "witness overflow") }
        for slot in 0 ..< n {
            let impl = try image.relative(c + UInt64(24 + slot * 8)); guard image.starts.contains(impl) else { continue }
            let wrapper = try instructions(image, impl)
            for call in wrapper where call.mnemonic == "bl" {
                guard let op = call.detail?.operands.first, op.type == .immediate, op.imm > 0, image.starts.contains(UInt64(op.imm)) else { continue }
                let body = try instructions(image, UInt64(op.imm))
                for k in 1 ..< body.count {
                    let prev = body[k - 1], branch = body[k]
                    guard prev.mnemonic == "cmp", let ops = prev.detail?.operands, ops.count == 2, ops[0].type == .register, ops[0].reg == .w(0), ops[1].type == .immediate, ops[1].imm == 1, branch.mnemonic == "b.ne" else { continue }
                    guard k >= 2, body[k - 2].mnemonic == "blraa",
                          let dest = branch.detail?.operands.first, dest.type == .immediate,
                          dest.imm > Int64(branch.address), let end = body.firstIndex(where: { $0.address == UInt64(dest.imm) }),
                          end > k, end - k <= 40 else { continue }
                    let fallthroughBlock = Array(body[(k + 1) ..< end].prefix(while: { $0.mnemonic != "b" && !$0.isReturn }))
                    guard fallthroughBlock.contains(where: { $0.mnemonic == "bl" }),
                          k + 1 + fallthroughBlock.count < end, body[k + 1 + fallthroughBlock.count].mnemonic == "b"
                    else {
                        print("REJECT", name, branch.description, "no cleanup call before merge")
                        continue
                    }
                    guard let replacement = ARM64Encoder.encodeB(from: Int(branch.address), to: Int(branch.address + 4)),
                          let decoded = decoder.disassembleOne(replacement, at: branch.address), decoded.mnemonic == "b",
                          decoded.detail?.operands.first?.imm == Int64(branch.address + 4) else { throw InvalidImage(description: "encoder round trip failed") }
                    sites[name, default: []].append((branch.address, replacement))
                    print(name, "witness", String(format: "0x%llx", impl), "body", String(format: "0x%llx", UInt64(op.imm)), "CANDIDATE", branch.description)
                    for x in body[k ..< min(k + 9, body.count)] {
                        print("  ", x.description)
                    }
                }
            }
        }
    }
    for (name, matches) in sites.sorted(by: { $0.key < $1.key }) {
        guard matches.count == 1 else { throw InvalidImage(description: "ambiguous sites for \(name)") }
        print("UNIQUE STRUCTURAL CANDIDATE", name, String(format: "0x%llx", matches[0].0), "replacement", matches[0].1.map { String(format: "%02x", $0) }.joined())
    }
    if let outIndex = CommandLine.arguments.firstIndex(of: "--output") {
        guard outIndex + 1 < CommandLine.arguments.count else { throw InvalidImage(description: "--output requires path") }
        let out = CommandLine.arguments[outIndex + 1]
        guard !FileManager.default.fileExists(atPath: out),!FileManager.default.fileExists(atPath: out + ".json") else { throw InvalidImage(description: "output already exists") }
        guard let selectIndex = CommandLine.arguments.firstIndex(of: "--providers"), selectIndex + 1 < CommandLine.arguments.count else { throw InvalidImage(description: "explicit --providers required") }
        let selected = Set(CommandLine.arguments[selectIndex + 1].split(separator: ",").map(String.init))
        guard !selected.isEmpty, selected.isSubset(of: wanted) else { throw InvalidImage(description: "unknown provider") }
        let hash = SHA256.hash(data: image.data).map { String(format: "%02x", $0) }.joined()
        let known: Set = ["e59851f14f29409590a6de76ca2fe9b9912341aee526a278692ef0d7a86ee2f3", "e43fa27956007aef6180570b242e3b08bb2030841121d13ac8671ec9f8480dd1"]
        guard known.contains(hash) else { throw InvalidImage(description: "unreviewed input hash; no output written") }
        var output = image.data; var changes: [[String: Any]] = []
        for name in selected.sorted() {
            guard let matches = sites[name], matches.count == 1 else { throw InvalidImage(description: "missing or ambiguous provider \(name)") }
            let (va, replacement) = matches[0]; let off = try image.offset(va)
            changes.append(["provider": name, "va": String(format: "0x%llx", va), "fileOffset": off, "before": output[off ..< off + 4].map { String(format: "%02x", $0) }.joined(), "after": replacement.map { String(format: "%02x", $0) }.joined()])
            output.replaceSubrange(off ..< off + 4, with: replacement)
        }
        let manifest: [String: Any] = ["status": "EXPERIMENTAL_NOT_DEPLOYMENT_APPROVED", "inputSHA256": hash, "outputSHA256": SHA256.hash(data: output).map { String(format: "%02x", $0) }.joined(), "changes": changes, "signature": "invalidated; not re-signed", "limitations": "Game Center unsupported. Extracted cache dylib is analysis-only. Runtime semantics and rollback unverified."]
        try output.write(to: URL(fileURLWithPath: out), options: .withoutOverwriting)
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: out + ".json"), options: .withoutOverwriting)
        print("EXPERIMENTAL COPY", out)
    }
} catch { fputs("ERROR: \(error)\n", stderr); exit(1) }
