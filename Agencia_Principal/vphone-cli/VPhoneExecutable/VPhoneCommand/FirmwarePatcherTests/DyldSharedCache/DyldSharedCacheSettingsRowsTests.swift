import CryptoKit
import Darwin
import FirmwarePatcher
import Foundation
import Testing

@Suite("Settings Software Update cache")
struct DyldSharedCacheSettingsRowsTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["VPHONE_SETTINGS_CACHE_FIXTURE"] != nil))
    func `fixture patch repeat and undo`() throws {
        let fm = FileManager.default
        let source = try URL(fileURLWithPath: #require(ProcessInfo.processInfo.environment["VPHONE_SETTINGS_CACHE_FIXTURE"]))
        let work = fm.temporaryDirectory.appendingPathComponent("settings-cache-test-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }
        for url in try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
            where url.lastPathComponent.hasPrefix("dyld_shared_cache_arm64e")
        {
            let to = work.appendingPathComponent(url.lastPathComponent)
            guard clonefile(url.path, to.path, 0) == 0 else { throw CocoaError(.fileWriteUnknown) }
        }
        let chunks = try DyldSharedCacheChunkSet(directory: work, captureUndo: true)
        let dry = try DyldSharedCacheSettingsRowsPatcher.patch(in: chunks, dryRun: true)
        #expect(!dry.alreadyPatched)
        #expect(chunks.takeUndoLog()?.records.isEmpty == true)
        let (file, _) = try chunks.fileRange(of: DyldSharedCacheWriteSpan(vma: dry.address, length: 4))
        let original = try Data(contentsOf: file)
        _ = try DyldSharedCacheSettingsRowsPatcher.patch(in: chunks)
        let patched = try Data(contentsOf: file)
        #expect(SHA256.hash(data: patched).map { String(format: "%02x", $0) }.joined()
            == "dd79a85eb90dbe9dab116220ad2a5cde32109054e6f8bef5bee9e131690240c4")
        var undo = try #require(chunks.takeUndoLog())
        #expect(undo.records.count == 1)
        undo.stamp(patchID: FirmwareGuestSystemPatchSet.settingsSoftwareUpdate)
        let repeatSite = try DyldSharedCacheSettingsRowsPatcher.patch(in: chunks)
        #expect(repeatSite.alreadyPatched)
        #expect(chunks.takeUndoLog()?.records.isEmpty == true)
        #expect(try Data(contentsOf: file) == patched)
        let spans = try undo.restore(patchIDs: undo.patchIDs, in: work)
        #expect(try DyldSharedCacheCodeSignature.reattest(in: chunks, modifiedSpans: spans).isFullyAttested)
        #expect(try Data(contentsOf: file) == original)
    }
}
