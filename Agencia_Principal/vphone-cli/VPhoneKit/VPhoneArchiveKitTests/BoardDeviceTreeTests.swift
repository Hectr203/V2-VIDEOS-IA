import Foundation
import Testing
@testable import VPhoneArchiveKit
import VPhoneCoreKit

/// Recovering an iPad VM's board device tree from the IPSW it was made from,
/// for the board audio repair `cfw update-environment` applies. Synthetic VM
/// folders and IPSWs only: a manifest and the members it names, no firmware.
@Suite("Board device tree recovery", .serialized)
struct BoardDeviceTreeTests {
    // MARK: - Fixtures

    private let iPadTree = "iPhoneOS_iPad16,1_26.6.2_23G90_Restore"

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// A VM folder whose `FirmwareOriginals` holds `trees`, each with the
    /// vphone600 trees `fw patch` keeps and the extra `files` given.
    private func makeVM(in root: URL, trees: [String], files: [String] = []) throws -> URL {
        let vm = root.appendingPathComponent("machines/ipad", isDirectory: true)
        try FileManager.default.createDirectory(at: vm, withIntermediateDirectories: true)
        for tree in trees {
            let flash = vm.appendingPathComponent("FirmwareOriginals/\(tree)/Firmware/all_flash", isDirectory: true)
            try FileManager.default.createDirectory(at: flash, withIntermediateDirectories: true)
            for name in ["DeviceTree.vphone600ap.im4p", "DeviceTree.vphone600ap.guest.im4p"] + files {
                try Data(name.utf8).write(to: flash.appendingPathComponent(name))
            }
        }
        return vm
    }

    /// An IPSW with a BuildManifest for `productTypes` and one build identity
    /// per board, each naming `Firmware/all_flash/DeviceTree.<board>.im4p`,
    /// and that member holding `"tree <board>"`.
    @discardableResult
    private func makeIPSW(
        _ name: String,
        in directory: URL,
        version: String = "26.6.2",
        build: String = "23G90",
        productTypes: [String] = ["iPad16,1", "iPad16,2"],
        boards: [String] = ["j410ap", "j411ap"],
        includeMembers: Bool = true,
    ) throws -> URL {
        let files = directory.appendingPathComponent(".\(UUID().uuidString)", isDirectory: true)
        let flash = files.appendingPathComponent("Firmware/all_flash", isDirectory: true)
        try FileManager.default.createDirectory(at: flash, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: files) }
        let identities: [[String: Any]] = boards.map { board in
            [
                "Info": ["DeviceClass": board],
                "Manifest": ["DeviceTree": ["Info": ["Path": "Firmware/all_flash/DeviceTree.\(board).im4p"]]],
            ]
        }
        let manifest: [String: Any] = [
            "ProductVersion": version,
            "ProductBuildVersion": build,
            "SupportedProductTypes": productTypes,
            "BuildIdentities": identities,
        ]
        try PropertyListSerialization.data(fromPropertyList: manifest, format: .xml, options: 0)
            .write(to: files.appendingPathComponent("BuildManifest.plist"))
        if includeMembers {
            for board in boards {
                try Data("tree \(board)".utf8).write(to: flash.appendingPathComponent("DeviceTree.\(board).im4p"))
            }
        }
        let archive = directory.appendingPathComponent(name)
        try VPhoneArchiveWriter.create(archive: archive, from: files)
        return archive
    }

    private var miniFirmware: VPhoneBoardDeviceTree.Firmware {
        .init(device: .iPad16_1, version: "26.6.2", build: "23G90")
    }

    // MARK: - Firmware

    @Test func `restore tree names read back into the firmware they name`() {
        let iPad = VPhoneBoardDeviceTree.firmware(treeName: iPadTree, device: .iPad16_1)
        #expect(iPad == miniFirmware)
        #expect(iPad?.keptPath == "FirmwareOriginals/\(iPadTree)/Firmware/all_flash/DeviceTree.j410ap.im4p")
        #expect(VPhoneBoardDeviceTree.firmware(treeName: "iPhone17,3_26.0_23A341_Restore", device: .iPhone17_3)?.build == "23A341")
        // Another device's tree, or not a restore tree at all.
        #expect(VPhoneBoardDeviceTree.firmware(treeName: iPadTree, device: .iPad15_7) == nil)
        #expect(VPhoneBoardDeviceTree.firmware(treeName: "Restore", device: .iPad16_1) == nil)
        #expect(VPhoneBoardDeviceTree.firmware(treeName: "iPhoneOS_iPad16,1__23G90_Restore", device: .iPad16_1) == nil)
    }

    // MARK: - Need

    @Test func `an iPhone VM recovers D47AP's tree for its product description`() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        // makeVM leaves only the vphone600 trees, which are not a board tree.
        let vm = try VPhoneConfinedDirectory(root: makeVM(in: root, trees: ["iPhone17,3_26.6.2_23G90_Restore"]).path)
        #expect(try VPhoneBoardDeviceTree.need(device: .iPhone17_3, in: vm, recorded: nil)
            == .recover(.init(device: .iPhone17_3, version: "26.6.2", build: "23G90")))
        #expect(VPhoneBoardDeviceTree.Firmware(device: .iPhone17_3, version: "26.6.2", build: "23G90").keptPath
            == "FirmwareOriginals/iPhone17,3_26.6.2_23G90_Restore/Firmware/all_flash/DeviceTree.d47ap.im4p")
    }

    @Test func `an iPad VM that kept its board tree needs nothing more`() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let vm = try VPhoneConfinedDirectory(root: makeVM(in: root, trees: [iPadTree], files: ["DeviceTree.j410ap.im4p"]).path)
        #expect(try VPhoneBoardDeviceTree.need(device: .iPad16_1, in: vm, recorded: nil) == .kept)
        #expect(try VPhoneBoardDeviceTree.kept(in: vm).map(\.path) == [
            "FirmwareOriginals/\(iPadTree)/Firmware/all_flash/DeviceTree.j410ap.im4p",
        ])
    }

    @Test func `an iPad VM without one recovers it for the firmware its originals name`() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let vm = try VPhoneConfinedDirectory(root: makeVM(in: root, trees: [iPadTree]).path)
        #expect(try VPhoneBoardDeviceTree.kept(in: vm).isEmpty)
        // The originals win over a restore-info.json that disagrees.
        let recorded = VPhoneRestoreInfo.OSVersion(version: "26.6.1", build: "23G80")
        #expect(try VPhoneBoardDeviceTree.need(device: .iPad16_1, in: vm, recorded: recorded) == .recover(miniFirmware))
    }

    @Test func `restore-info answers only when the originals cannot`() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let vm = try VPhoneConfinedDirectory(root: makeVM(in: root, trees: []).path)
        let recorded = VPhoneRestoreInfo.OSVersion(version: "26.6.2", build: "23G90")
        #expect(try VPhoneBoardDeviceTree.need(device: .iPad16_1, in: vm, recorded: recorded) == .recover(miniFirmware))
        #expect(try VPhoneBoardDeviceTree.need(device: .iPad16_1, in: vm, recorded: nil) == .unidentified)

        // Two trees for the device are not guessed between.
        let twice = try VPhoneConfinedDirectory(root: makeVM(
            in: root.appendingPathComponent("second"),
            trees: [iPadTree, "iPhoneOS_iPad16,1_26.6.1_23G80_Restore"],
        ).path)
        #expect(try VPhoneBoardDeviceTree.need(device: .iPad16_1, in: twice, recorded: recorded) == .unidentified)
    }

    // MARK: - IPSW

    @Test func `the IPSW is chosen by its manifest, not its name`() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = root.appendingPathComponent("ipsws", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        // Named like the right one, but another build.
        try makeIPSW("iPad16,1,iPad16,2_26.6.2_23G90_Restore.ipsw", in: cache, version: "26.6.1", build: "23G80")
        // The right build for other iPads.
        try makeIPSW("a.ipsw", in: cache, productTypes: ["iPad17,1", "iPad17,2"], boards: ["j817ap"])
        // Not an archive at all, and a partial download.
        try Data("not an ipsw".utf8).write(to: cache.appendingPathComponent("b.ipsw"))
        try makeIPSW(".c.ipsw.partial", in: cache)
        // The one, cellular model only in its product list.
        let right = try makeIPSW("z.ipsw", in: cache, productTypes: ["iPad16,2"])

        let source = try #require(VPhoneBoardDeviceTree.find(miniFirmware, in: [root.appendingPathComponent("missing"), cache]))
        #expect(source.archive == right)
        #expect(source.member == "Firmware/all_flash/DeviceTree.j410ap.im4p")
        #expect(source.contents == Data("tree j410ap".utf8))
    }

    @Test func `no IPSW is found when none carries the board tree`() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try makeIPSW("x.ipsw", in: root, boards: ["j411ap"])
        try makeIPSW("y.ipsw", in: root, includeMembers: false)
        #expect(VPhoneBoardDeviceTree.find(miniFirmware, in: [root]) == nil)
    }

    @Test func `the library's own ipsws folder is searched after the shared cache`() {
        let vm = URL(fileURLWithPath: "/Volumes/Lab/vphone/machines/ipad", isDirectory: true)
        let directories = VPhoneBoardDeviceTree.searchDirectories(forVirtualMachineAt: vm)
        #expect(directories.first == VPhoneResources.ipswCacheDirectory())
        #expect(directories.last?.path == "/Volumes/Lab/vphone/ipsws")

        let local = VPhoneResources.ipswCacheDirectory().deletingLastPathComponent()
            .appendingPathComponent("machines/ipad", isDirectory: true)
        #expect(VPhoneBoardDeviceTree.searchDirectories(forVirtualMachineAt: local).count == 1)
    }

    // MARK: - Store

    @Test func `a recovered tree is kept where fw patch keeps it`() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = try makeVM(in: root, trees: [iPadTree])
        let vm = try VPhoneConfinedDirectory(root: url.path)
        let source = try #require(VPhoneBoardDeviceTree.find(miniFirmware, in: [makeIPSWDirectory(in: root)]))

        let path = try VPhoneBoardDeviceTree.store(source, for: miniFirmware, in: vm)
        #expect(path == miniFirmware.keptPath)
        let file = url.appendingPathComponent(path)
        #expect(try Data(contentsOf: file) == Data("tree j410ap".utf8))
        let mode = try #require(FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int)
        #expect(mode == 0o777)
        // A later run finds it like one fw patch kept.
        #expect(try VPhoneBoardDeviceTree.need(device: .iPad16_1, in: vm, recorded: nil) == .kept)
    }

    @Test func `storing creates the originals folders a VM never had`() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = try makeVM(in: root, trees: [])
        let vm = try VPhoneConfinedDirectory(root: url.path)
        let source = try #require(VPhoneBoardDeviceTree.find(miniFirmware, in: [makeIPSWDirectory(in: root)]))

        try VPhoneBoardDeviceTree.store(source, for: miniFirmware, in: vm)
        for folder in ["FirmwareOriginals", "FirmwareOriginals/\(iPadTree)/Firmware/all_flash"] {
            let mode = try #require(
                FileManager.default.attributesOfItem(atPath: url.appendingPathComponent(folder).path)[.posixPermissions] as? Int,
            )
            #expect(mode == 0o777)
        }
        #expect(try VPhoneBoardDeviceTree.kept(in: vm).map(\.name) == ["DeviceTree.j410ap.im4p"])
    }

    private func makeIPSWDirectory(in root: URL) throws -> URL {
        let directory = root.appendingPathComponent("ipsws", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try makeIPSW("mini.ipsw", in: directory)
        return directory
    }
}
