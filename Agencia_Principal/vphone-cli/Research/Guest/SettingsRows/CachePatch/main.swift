import CryptoKit
import Foundation
import VPhonePatchKit

struct Failure: Error { let message: String }
func require(_ ok: Bool, _ message: String) throws {
    if !ok {
        throw Failure(message: message)
    }
}

func hash(_ d: Data) -> String {
    SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
}

func hex(_ s: String) -> Data {
    Data(stride(from: 0, to: s.count, by: 2).map { let i = s.index(s.startIndex, offsetBy: $0); return UInt8(s[i ..< s.index(i, offsetBy: 2)], radix: 16)! })
}

do {
    let args = CommandLine.arguments
    try require(args.count == 5, "usage: tool original-chunk extracted-image discovery-manifest output-directory")
    let source = URL(fileURLWithPath: args[1]), fixture = try Data(contentsOf: URL(fileURLWithPath: args[2]))
    let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: args[3]))) as! [String: Any]
    try require(hash(fixture) == manifest["inputSHA256"] as? String, "extracted fixture hash mismatch")
    let changes = manifest["changes"] as! [[String: Any]]
    try require(changes.count == 1 && changes[0]["provider"] as? String == "SoftwareUpdateListItemProvider", "unexpected discovery manifest")
    let c = changes[0], va = UInt64((c["va"] as! String).dropFirst(2), radix: 16)!, fo = c["fileOffset"] as! Int
    let before = hex(c["before"] as! String), after = hex(c["after"] as! String)
    try require(before.count == 4 && ARM64Encoder.encodeB(from: Int(va), to: Int(va + 4)) == after, "invalid replacement")
    let original = try Data(contentsOf: source)
    let dir = URL(fileURLWithPath: args[4]), out = dir.appendingPathComponent("dyld_shared_cache_arm64e.36")
    try require(!FileManager.default.fileExists(atPath: out.path), "output exists")
    try FileManager.default.copyItem(at: source, to: out)
    let chunks = try DyldSharedCacheChunkSet(directory: dir, captureUndo: true)
    try require(chunks.readAtVMA(va, length: 4) == before, "cache site mismatch")
    try require(fo >= 128 && fo + 132 <= fixture.count, "fixture bounds")
    try require(chunks.readAtVMA(va - 128, length: 260) == fixture.subdata(in: (fo - 128) ..< (fo + 132)), "surrounding code differs from reviewed image")
    try chunks.write(at: va, after)
    let report = try DyldSharedCacheCodeSignature.reattestRecordedWrites(in: chunks)
    try require(report.skipped.isEmpty, "signature pages skipped")
    if let undo = chunks.takeUndoLog() {
        try JSONEncoder().encode(undo).write(to: dir.appendingPathComponent("software-update-undo.json"), options: .withoutOverwriting)
    }
    let patched = try Data(contentsOf: out)
    let (url, range) = try chunks.fileRange(of: DyldSharedCacheWriteSpan(vma: va, length: 4))
    guard let cd = try DyldSharedCacheCodeSignature.readCodeDirectory(ofChunk: url) else { throw Failure(message: "no code directory") }
    let page = range.lowerBound / cd.pageSize, slot = cd.slotOffset(forPage: page)
    try require(Data(SHA256.hash(data: patched.subdata(in: page * cd.pageSize ..< (page + 1) * cd.pageSize))) == patched.subdata(in: slot ..< slot + 32), "hash validation failed")
    try require(original.count == patched.count, "size changed")
    var count = 0
    for i in original.indices where original[i] != patched[i] {
        try require(range.contains(i) || (slot ..< slot + 32).contains(i), "unexpected changed byte"); count += 1
    }
    print("sourceSHA256=\(hash(original)) outputSHA256=\(hash(patched)) changedBytes=\(count) site=\(range) page=\(page) hashSlot=\(slot)")
} catch { fputs("ERROR: \(error)\n", stderr); exit(1) }
