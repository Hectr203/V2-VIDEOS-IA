import Darwin
import Foundation
import Testing
@testable import VPhoneCoreKit

/// The offline trim of a template's System volume: the tier lists, the path
/// rules, applying a trim to a folder laid out like the volume, and reading
/// the disk layout from `diskutil image attach` and `diskutil` output.
struct SystemTrimTests {
    // MARK: - Lists

    @Test func `each tier contains the one below it and none deletes nothing`() throws {
        #expect(VPhoneSystemTrimSpec.none.entries.isEmpty)
        let conservative = try VPhoneSystemTrimSpec(tier: .conservative).entries.map(\.path)
        let standard = VPhoneSystemTrimSpec.standard.entries.map(\.path)
        #expect(conservative == ["usr/standalone/update"])
        #expect(Set(conservative).isSubset(of: Set(standard)))
        #expect(standard.count == 4)
        #expect(VPhoneSystemTrimTier.none < .conservative && .conservative < .standard && .standard < .aggressive)
    }

    @Test func `entries are relative, safe and do not overlap`() {
        let entries = VPhoneSystemTrim.entries(keptLanguages: VPhoneSystemTrim.defaultKeptLanguages)
        for entry in entries {
            #expect(VPhoneSystemTrim.isSafeRelativePath(entry.path), "\(entry.path)")
            #expect(!entry.path.hasPrefix("/"))
            #expect(!entry.note.isEmpty)
        }
        for (i, a) in entries.enumerated() {
            for b in entries[(i + 1)...] {
                #expect(a.path != b.path)
                #expect(!a.path.hasPrefix(b.path + "/"), "\(a.path) is inside \(b.path)")
                #expect(!b.path.hasPrefix(a.path + "/"), "\(b.path) is inside \(a.path)")
            }
        }
        // Never on any list: the dyld cache and its symbols, ML models, apps.
        let all = entries.map(\.path).joined(separator: "\n")
        for forbidden in ["dyld", "Cryptexes", "Applications", ".mlmodelc", "symbols"] {
            #expect(!all.contains(forbidden), "\(forbidden)")
        }
    }

    @Test func `path rules refuse anything that could leave the volume`() {
        for good in ["a", "a/b", "System/Library/x.bundle"] {
            #expect(VPhoneSystemTrim.isSafeRelativePath(good))
        }
        for bad in ["", "/a", "a/../b", "..", ".", "a//b", "a/", "a/./b", "a\u{0}b"] {
            #expect(!VPhoneSystemTrim.isSafeRelativePath(bad), "\(bad)")
        }
    }

    @Test func `aggressive is reserved and refused`() {
        #expect(!VPhoneSystemTrimTier.aggressive.isSupported)
        #expect(throws: VPhoneSystemTrimError.unsupportedTier("aggressive")) {
            try VPhoneSystemTrimTier.parse("aggressive")
        }
        #expect(throws: VPhoneSystemTrimError.unsupportedTier("aggressive")) {
            try VPhoneSystemTrimSpec(tier: .aggressive)
        }
        #expect(throws: VPhoneSystemTrimError.unknownTier("heavy")) {
            try VPhoneSystemTrimTier.parse("heavy")
        }
    }

    @Test func `kept languages default to en, zh-Hans and zh, and en is always kept`() throws {
        #expect(VPhoneSystemTrimSpec.standard.keptLanguages == ["en", "zh", "zh-Hans"])
        #expect(try VPhoneSystemTrimSpec(tier: .standard) == .standard)
        #expect(try VPhoneSystemTrimSpec.parse(tier: "standard", keptLanguages: "ja, fr").keptLanguages == ["en", "fr", "ja"])
        // A tier without language data keeps no list.
        #expect(try VPhoneSystemTrimSpec(tier: .conservative).keptLanguages.isEmpty)
        #expect(throws: VPhoneSystemTrimError.languagesUnused("conservative")) {
            try VPhoneSystemTrimSpec.parse(tier: "conservative", keptLanguages: "en")
        }
        #expect(throws: VPhoneSystemTrimError.invalidLanguage("../x")) {
            try VPhoneSystemTrimSpec.parse(tier: "standard", keptLanguages: "../x")
        }
    }

    @Test func `the key value names tier, list version and kept languages, and reads back`() throws {
        #expect(VPhoneSystemTrimSpec.none.keyValue == "none")
        #expect(try VPhoneSystemTrimSpec(tier: .conservative).keyValue == "conservative/\(VPhoneSystemTrim.listVersion)")
        #expect(VPhoneSystemTrimSpec.standard.keyValue == "standard/\(VPhoneSystemTrim.listVersion)/en,zh,zh-Hans")
        for spec in try [VPhoneSystemTrimSpec.none, .standard, VPhoneSystemTrimSpec(tier: .conservative),
                         VPhoneSystemTrimSpec(tier: .standard, keptLanguages: ["ja"])]
        {
            #expect(try VPhoneSystemTrimSpec(keyValue: spec.keyValue) == spec)
        }
        #expect(throws: VPhoneSystemTrimError.unavailableListVersion(99)) {
            try VPhoneSystemTrimSpec(keyValue: "standard/99/en")
        }
        #expect(throws: VPhoneSystemTrimError.self) { try VPhoneSystemTrimSpec(keyValue: "standard/1") }
        #expect(throws: VPhoneSystemTrimError.self) { try VPhoneSystemTrimSpec(keyValue: "standard/1/zh,en") }
        #expect(VPhoneSystemTrimSpec.tier(ofKeyValue: "standard/7/en") == .standard)
        #expect(VPhoneSystemTrimSpec.tier(ofKeyValue: "none") == VPhoneSystemTrimTier.none)
        #expect(VPhoneSystemTrimSpec.tier(ofKeyValue: "bogus") == nil)
    }

    @Test func `a trim permits only what its entries select`() throws {
        let spec = VPhoneSystemTrimSpec.standard
        #expect(spec.permits("usr/standalone/update/Mav24.Release.bbfw"))
        #expect(spec.permits("System/Library/PreinstalledAssetsV2/RequiredByOs/com_apple_MobileAsset_SharingDeviceAssets"))
        #expect(spec.permits("System/Library/NanoTimeKit/FaceBundles/Kaleidoscope.bundle"))
        #expect(spec.permits("System/Library/LinguisticData/RequiredAssets_ja.bundle"))

        for kept in ["en", "zh-Hans", "zh"] {
            #expect(!spec.permits("System/Library/LinguisticData/RequiredAssets_\(kept).bundle"), "\(kept)")
        }
        #expect(!spec.permits("System/Library/LinguisticData/ja"))
        #expect(!spec.permits("System/Library/LinguisticData/Info.plist"))
        #expect(!spec.permits("usr/standalone/update")) // the folder itself stays
        #expect(!spec.permits("usr/standalone/update/ramdisk/arm64eSURamDisk.dmg")) // only direct children
        #expect(!spec.permits("usr/standalone/update/.."))
        #expect(!spec.permits("usr/standalone/update/../../../etc"))
        #expect(!spec.permits("/usr/standalone/update/x"))
        #expect(!spec.permits("System/Library/Caches/com.apple.dyld"))
        // Conservative stops at its own entry.
        #expect(try !VPhoneSystemTrimSpec(tier: .conservative).permits("System/Library/NanoTimeKit/FaceBundles/x"))
        #expect(!VPhoneSystemTrimSpec.none.permits("usr/standalone/update/x"))
    }

    @Test func `a recorded trim can only be repeated or widened from conservative`() throws {
        let conservative = try VPhoneSystemTrimSpec(tier: .conservative)
        let standard = VPhoneSystemTrimSpec.standard
        let japanese = try VPhoneSystemTrimSpec(tier: .standard, keptLanguages: ["ja"])
        #expect(standard.canFollow(recorded: "none"))
        #expect(standard.canFollow(recorded: standard.keyValue))
        #expect(standard.canFollow(recorded: conservative.keyValue))
        #expect(!conservative.canFollow(recorded: standard.keyValue))
        #expect(!VPhoneSystemTrimSpec.none.canFollow(recorded: conservative.keyValue))
        #expect(!japanese.canFollow(recorded: standard.keyValue))
        #expect(!standard.canFollow(recorded: "garbage"))
    }

    @Test func `a create naming another trim than the template has conflicts`() throws {
        let slimmed = VPhoneTemplateSlimmingRequest.defaultSlimming
        let key = MachineTemplateKeyTests.key(slimming: slimmed)
        #expect(slimmed.trimTier == VPhoneSystemTrimSpec.standard.keyValue)
        #expect(VPhoneMachineTemplateRequest(slimming: slimmed).conflicts(with: key).isEmpty)
        let untrimmed = try VPhoneTemplateSlimmingRequest(trimTier: "none").resolve()
        #expect(VPhoneMachineTemplateRequest(slimming: untrimmed).conflicts(with: key).count == 1)
        #expect(VPhoneMachineTemplateRequest().conflicts(with: key).isEmpty)
    }

    // MARK: - Applying

    private struct Volume {
        let root: URL
        let outside: URL

        func cleanUp() {
            try? FileManager.default.removeItem(at: root.deletingLastPathComponent())
        }

        func exists(_ relative: String) -> Bool {
            var info = stat()
            return lstat(root.appendingPathComponent(relative).path, &info) == 0
        }
    }

    /// A folder laid out like the parts of a System volume the lists name,
    /// with a sibling folder outside it that must survive everything.
    private func makeVolume(system: Bool = true) throws -> Volume {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("trim-\(UUID().uuidString)")
        let root = base.appendingPathComponent("system")
        let outside = base.appendingPathComponent("outside")
        try fm.createDirectory(at: outside, withIntermediateDirectories: true)
        try Data(repeating: 7, count: 40000).write(to: outside.appendingPathComponent("precious"))
        func file(_ relative: String, _ size: Int = 20000) throws {
            let url = root.appendingPathComponent(relative)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(repeating: 1, count: size).write(to: url)
        }
        if system {
            try file(VPhoneSystemTrim.systemVolumeMarker, 100)
        }
        try file("usr/standalone/update/Mav24.Release.bbfw")
        try file("usr/standalone/update/ramdisk/arm64eSURamDisk.dmg")
        try file("usr/standalone/firmware/keep.bin")
        try file("System/Library/PreinstalledAssetsV2/RequiredByOs/com_apple_MobileAsset_SharingDeviceAssets/a.asset/x")
        try file("System/Library/PreinstalledAssetsV2/RequiredByOs/com_apple_MobileAsset_ContextKit/keep")
        try file("System/Library/NanoTimeKit/FaceBundles/Kaleidoscope.bundle/Info.plist")
        for language in ["en", "zh-Hans", "zh", "ja", "fr"] {
            try file("System/Library/LinguisticData/RequiredAssets_\(language).bundle/data")
        }
        try file("System/Library/LinguisticData/ja/lexicon")
        try file("System/Library/LinguisticData/Info.plist", 10)
        // A link in a trimmed folder points out of the volume: it goes as a
        // link, and what it points at stays.
        try fm.createSymbolicLink(at: root.appendingPathComponent("usr/standalone/update/escape"), withDestinationURL: outside)
        return Volume(root: root, outside: outside)
    }

    @Test func `standard deletes its entries, keeps everything else, and never follows a link out`() throws {
        let volume = try makeVolume()
        defer { volume.cleanUp() }
        let root = try VPhoneConfinedDirectory(root: volume.root.path)
        var lines: [String] = []

        let result = try VPhoneSystemTrimSpec.standard.apply(to: root) { lines.append($0) }

        #expect(result.trim == VPhoneSystemTrimSpec.standard.keyValue)
        #expect(result.entries.map(\.path) == VPhoneSystemTrimSpec.standard.entries.map(\.path))
        #expect(result.entries.allSatisfy { !$0.absent })
        #expect(result.entries[0].removed == ["Mav24.Release.bbfw", "escape", "ramdisk"])
        #expect(result.entries[3].removed == ["RequiredAssets_fr.bundle", "RequiredAssets_ja.bundle"])
        #expect(result.bytes >= 6 * 20000)
        #expect(lines.count == 4)

        #expect(volume.exists("usr/standalone/update"))
        #expect(!volume.exists("usr/standalone/update/Mav24.Release.bbfw"))
        #expect(!volume.exists("usr/standalone/update/escape"))
        #expect(volume.exists("usr/standalone/firmware/keep.bin"))
        #expect(!volume.exists("System/Library/PreinstalledAssetsV2/RequiredByOs/com_apple_MobileAsset_SharingDeviceAssets"))
        #expect(volume.exists("System/Library/PreinstalledAssetsV2/RequiredByOs/com_apple_MobileAsset_ContextKit/keep"))
        #expect(volume.exists("System/Library/NanoTimeKit/FaceBundles"))
        #expect(!volume.exists("System/Library/NanoTimeKit/FaceBundles/Kaleidoscope.bundle"))
        for language in ["en", "zh-Hans", "zh"] {
            #expect(volume.exists("System/Library/LinguisticData/RequiredAssets_\(language).bundle"))
        }
        #expect(!volume.exists("System/Library/LinguisticData/RequiredAssets_ja.bundle"))
        #expect(volume.exists("System/Library/LinguisticData/ja/lexicon"))
        #expect(volume.exists("System/Library/LinguisticData/Info.plist"))
        #expect(FileManager.default.fileExists(atPath: volume.outside.appendingPathComponent("precious").path))

        // Again: nothing left to delete, nothing absent either.
        let again = try VPhoneSystemTrimSpec.standard.apply(to: root)
        #expect(again.bytes == 0)
        // A key path here makes #expect's expansion fail to compile.
        // swiftformat:disable:next preferKeyPath
        #expect(again.entries.allSatisfy { $0.removed.isEmpty })
    }

    @Test func `conservative stops at usr standalone update`() throws {
        let volume = try makeVolume()
        defer { volume.cleanUp() }
        let result = try VPhoneSystemTrimSpec(tier: .conservative).apply(to: VPhoneConfinedDirectory(root: volume.root.path))
        #expect(result.entries.map(\.path) == ["usr/standalone/update"])
        #expect(volume.exists("System/Library/NanoTimeKit/FaceBundles/Kaleidoscope.bundle"))
        #expect(volume.exists("System/Library/LinguisticData/RequiredAssets_ja.bundle"))
    }

    @Test func `a listed folder that is a link is refused, not followed`() throws {
        let volume = try makeVolume()
        defer { volume.cleanUp() }
        let faces = volume.root.appendingPathComponent("System/Library/NanoTimeKit/FaceBundles")
        try FileManager.default.removeItem(at: faces)
        try FileManager.default.createSymbolicLink(at: faces, withDestinationURL: volume.outside)

        #expect(throws: VPhoneConfinedDirectoryError.self) {
            try VPhoneSystemTrimSpec.standard.apply(to: VPhoneConfinedDirectory(root: volume.root.path))
        }
        #expect(FileManager.default.fileExists(atPath: volume.outside.appendingPathComponent("precious").path))
    }

    @Test func `missing entries are reported absent`() throws {
        let volume = try makeVolume()
        defer { volume.cleanUp() }
        try FileManager.default.removeItem(at: volume.root.appendingPathComponent("System/Library/NanoTimeKit"))
        try FileManager.default.removeItem(at: volume.root.appendingPathComponent(
            "System/Library/PreinstalledAssetsV2/RequiredByOs/com_apple_MobileAsset_SharingDeviceAssets",
        ))
        let result = try VPhoneSystemTrimSpec.standard.apply(to: VPhoneConfinedDirectory(root: volume.root.path))
        #expect(result.entries.map(\.absent) == [false, true, true, false])
    }

    @Test func `a volume without the iOS marker is refused before anything is deleted`() throws {
        let volume = try makeVolume(system: false)
        defer { volume.cleanUp() }
        #expect(throws: VPhoneSystemTrimError.notSystemVolume) {
            try VPhoneSystemTrimSpec.standard.apply(to: VPhoneConfinedDirectory(root: volume.root.path))
        }
        #expect(volume.exists("usr/standalone/update/Mav24.Release.bbfw"))
    }

    @Test func `removal reports allocated bytes and counts a second hard link as nothing`() throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("rm-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: base) }
        try fm.createDirectory(at: base.appendingPathComponent("d"), withIntermediateDirectories: true)
        try Data(repeating: 1, count: 100_000).write(to: base.appendingPathComponent("d/a"))
        try Data(repeating: 2, count: 100_000).write(to: base.appendingPathComponent("b"))
        try fm.linkItem(at: base.appendingPathComponent("b"), to: base.appendingPathComponent("d/b-link"))
        let root = try VPhoneConfinedDirectory(root: base.path)

        let removed = try root.removeItem("d")
        #expect(removed >= 100_000 && removed < 200_000)
        #expect(try root.removeItem("missing") == 0)
    }

    // MARK: - Disk layout

    @Test func `the attached disk and its APFS store come from diskutil image attach output`() {
        // `diskutil image attach -noMount` of a guest Disk.img on macOS 27.0.1,
        // byte for byte: the image's disk first, then the synthesized container.
        let output = "/dev/disk8  \tGUID_partition_scheme\n/dev/disk8s1\tApple_APFS\n"
            + "/dev/disk9  \tApple_APFS_Container\n"
            + (1 ... 7).map { "/dev/disk9s\($0)\tApple_APFS_Volume\n" }.joined()
        let disks = VPhoneGuestDiskLayout.attachedDisks(fromAttachOutput: output)
        #expect(disks.wholeDisk == "disk8")
        #expect(disks.store == "disk8s1")
        // The container's lines first, as `hdiutil attach` printed them on
        // macOS 27, still give the image's own disk.
        let containerFirst = "/dev/disk9  \tApple_APFS_Container\n/dev/disk9s1\tApple_APFS_Volume\n"
            + "/dev/disk8  \tGUID_partition_scheme\n/dev/disk8s1\tApple_APFS\n"
        let reordered = VPhoneGuestDiskLayout.attachedDisks(fromAttachOutput: containerFirst)
        #expect(reordered.wholeDisk == "disk8")
        #expect(reordered.store == "disk8s1")
        // Without the partition-scheme line the store's parent is the disk.
        #expect(VPhoneGuestDiskLayout.attachedDisks(fromAttachOutput: "/dev/disk8s1\tApple_APFS\n").wholeDisk == "disk8")
        #expect(VPhoneGuestDiskLayout.attachedDisks(fromAttachOutput: "").wholeDisk == nil)
        #expect(VPhoneGuestDiskLayout.isDeviceName("disk12s3"))
        #expect(!VPhoneGuestDiskLayout.isDeviceName("/dev/disk1"))
        #expect(!VPhoneGuestDiskLayout.isDeviceName("disk1;rm"))
    }

    private func apfsList(container: String = "disk7", store: String = "disk6s1", systemRoles: [[String]]) throws -> Data {
        let volumes: [[String: Any]] = systemRoles.enumerated().map { index, roles in
            ["DeviceIdentifier": "\(container)s\(index + 1)", "Roles": roles, "Name": "v\(index)"]
        }
        let plist: [String: Any] = ["Containers": [[
            "ContainerReference": container,
            "PhysicalStores": [["DeviceIdentifier": store]],
            "Volumes": volumes,
        ]]]
        return try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    }

    @Test func `the System volume is found by role, on the attached store only`() throws {
        let data = try apfsList(systemRoles: [["Data"], ["Preboot"], ["System"], ["xART"]])
        #expect(try VPhoneGuestDiskLayout.systemVolume(fromAPFSList: data, container: "disk7", physicalStore: "disk6s1") == "disk7s3")
        #expect(throws: VPhoneSystemTrimError.self) {
            try VPhoneGuestDiskLayout.systemVolume(fromAPFSList: data, container: "disk7", physicalStore: "disk9s1")
        }
        #expect(throws: VPhoneSystemTrimError.self) {
            try VPhoneGuestDiskLayout.systemVolume(fromAPFSList: data, container: "disk8", physicalStore: "disk6s1")
        }
        let none = try apfsList(systemRoles: [["Data"]])
        #expect(throws: VPhoneSystemTrimError.self) {
            try VPhoneGuestDiskLayout.systemVolume(fromAPFSList: none, container: "disk7", physicalStore: "disk6s1")
        }
        let two = try apfsList(systemRoles: [["System"], ["System"]])
        #expect(throws: VPhoneSystemTrimError.self) {
            try VPhoneGuestDiskLayout.systemVolume(fromAPFSList: two, container: "disk7", physicalStore: "disk6s1")
        }
    }
}
