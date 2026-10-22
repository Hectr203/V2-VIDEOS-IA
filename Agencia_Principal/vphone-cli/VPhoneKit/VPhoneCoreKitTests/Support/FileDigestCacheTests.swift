import CryptoKit
import Foundation
import Testing
@testable import VPhoneCoreKit

struct FileDigestCacheTests {
    @Test func `an unchanged file is hashed once`() throws {
        let url = try Self.makeFile(Data("vphoned".utf8))
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var cache = VPhoneFileDigestCache()
        let first = cache.sha256(of: url)
        for _ in 0 ..< 100 {
            #expect(cache.sha256(of: url) == first)
        }
        #expect(first == Self.hex(Data("vphoned".utf8)))
        #expect(cache.hashCount == 1)
    }

    @Test func `a rewritten file is hashed again`() throws {
        let url = try Self.makeFile(Data("old build".utf8))
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var cache = VPhoneFileDigestCache()
        _ = cache.sha256(of: url)
        // Same size, later modification time.
        try Data("new build".utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(5)], ofItemAtPath: url.path)
        #expect(cache.sha256(of: url) == Self.hex(Data("new build".utf8)))
        #expect(cache.hashCount == 2)
    }

    @Test func `a file replaced by a rename is hashed again`() throws {
        let url = try Self.makeFile(Data("A".utf8))
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var cache = VPhoneFileDigestCache()
        _ = cache.sha256(of: url)
        let replacement = url.deletingLastPathComponent().appendingPathComponent("next")
        try Data("B".utf8).write(to: replacement)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        try FileManager.default.setAttributes([.modificationDate: attributes[.modificationDate] as Any],
                                              ofItemAtPath: replacement.path)
        _ = try FileManager.default.replaceItemAt(url, withItemAt: replacement)
        #expect(cache.sha256(of: url) == Self.hex(Data("B".utf8)))
    }

    @Test func `another path is hashed on its own`() throws {
        let a = try Self.makeFile(Data("A".utf8))
        let b = try Self.makeFile(Data("B".utf8))
        defer {
            try? FileManager.default.removeItem(at: a.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: b.deletingLastPathComponent())
        }
        var cache = VPhoneFileDigestCache()
        #expect(cache.sha256(of: a) == Self.hex(Data("A".utf8)))
        #expect(cache.sha256(of: b) == Self.hex(Data("B".utf8)))
    }

    @Test func `a missing file has no digest and forgets the old one`() throws {
        let url = try Self.makeFile(Data("A".utf8))
        var cache = VPhoneFileDigestCache()
        _ = cache.sha256(of: url)
        try FileManager.default.removeItem(at: url.deletingLastPathComponent())
        #expect(cache.sha256(of: url) == nil)
    }

    private static func makeFile(_ data: Data) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileDigestCacheTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("vphoned")
        try data.write(to: url)
        return url
    }

    private static func hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
