import Darwin
import Foundation
import VPhoneCoreKit

/// A guest's own device tree, `DeviceTree.<board>.im4p`, as a VM folder
/// keeps it and as the IPSW the VM was made from carries it: a board-presenting
/// guest's for its audio node, an iPhone17,3's (`DeviceTree.d47ap.im4p`) for its
/// product description.
///
/// `fw patch` keeps the tree in the VM's `FirmwareOriginals`, mirrored under
/// the restore tree's name, and the board audio repair that `cfw install` and
/// `cfw update-environment` apply to the Preboot device tree reads it from
/// there. A VM patched by a build that did not keep it has none, and nothing
/// else in the VM folder still holds it: the restore tree is deleted once the
/// VM has booted. The IPSW usually still exists, in the cache `fw prepare`
/// downloads into, so the tree is recovered from there — matched by what the
/// IPSW's BuildManifest says, never by its file name, and read as one member
/// without unpacking the rest.
///
/// Everything here takes the VM folder as a pinned `VPhoneConfinedDirectory`,
/// because the installer that calls it runs as root against a folder the
/// caller controls; see `VPhoneCustomFirmwareInstaller`.
public enum VPhoneBoardDeviceTree {
    // MARK: - Firmware

    /// The firmware a VM was made from, as far as its board tree is concerned.
    public struct Firmware: Equatable, Sendable {
        public let device: VPhoneGuestDevice
        public let version: String
        public let build: String

        public init(device: VPhoneGuestDevice, version: String, build: String) {
            self.device = device
            self.version = version
            self.build = build
        }

        /// The restore tree's name, which `FirmwareOriginals` mirrors.
        public var treeName: String {
            device.restoreTreeName(version: version, build: build)
        }

        /// `DeviceTree.<board>.im4p`.
        public var fileName: String {
            (device.boardDeviceTreePath as NSString).lastPathComponent
        }

        /// Where `fw patch` keeps the tree, relative to the VM folder.
        public var keptPath: String {
            "\(originalsName)/\(treeName)/\(device.boardDeviceTreePath)"
        }
    }

    /// Read `<treeName>` back into the version and build it was made from, for
    /// `device`. Nil for a folder another device or naming scheme made.
    public static func firmware(treeName: String, device: VPhoneGuestDevice) -> Firmware? {
        let suffix = "_Restore"
        guard treeName.hasSuffix(suffix) else { return nil }
        let parts = treeName.dropLast(suffix.count).split(separator: "_", omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return nil }
        let firmware = Firmware(device: device, version: String(parts[parts.count - 2]), build: String(parts[parts.count - 1]))
        guard !firmware.version.isEmpty, !firmware.build.isEmpty, firmware.treeName == treeName else { return nil }
        return firmware
    }

    // MARK: - Kept trees

    public struct Kept {
        /// The `all_flash` folder holding it.
        public let directory: VPhoneConfinedDirectory
        public let name: String
        /// Relative to the VM folder, for messages.
        public let path: String
    }

    static let originalsName = VPhoneBundleOperations.firmwareOriginalsDirectoryName

    /// Every board tree in the VM's `FirmwareOriginals`: any
    /// `DeviceTree.*.im4p` there that is not one of the vphone600 trees the
    /// boot chain is built from. Reached without following a link.
    public static func kept(in vm: VPhoneConfinedDirectory) throws -> [Kept] {
        guard try vm.isDirectory(originalsName) else { return [] }
        let stash = try vm.directory(originalsName)
        var found: [Kept] = []
        for tree in try stash.entries() where try stash.isDirectory(tree) {
            let flash = "\(tree)/Firmware/all_flash"
            guard try stash.isDirectory(flash) else { continue }
            let directory = try stash.directory(flash)
            for name in try directory.entries()
                where name.hasPrefix("DeviceTree.") && name.hasSuffix(".im4p")
                && !name.hasPrefix("DeviceTree.vphone600") && (try? directory.isRegularFile(name)) == true
            {
                found.append(Kept(directory: directory, name: name, path: "\(originalsName)/\(flash)/\(name)"))
            }
        }
        return found
    }

    // MARK: - Need

    /// What a run has to do about a VM's board tree.
    public enum Need: Equatable {
        /// Nothing to do. Every guest has a board tree now — a board-presenting
        /// guest's carries its audio node, an iPhone17,3's its product
        /// description — so `need` does not answer this; it stays for callers
        /// that switch over `Need`.
        case none
        /// `FirmwareOriginals` already holds one, or several, which staging
        /// refuses to choose between.
        case kept
        /// None is kept; this is the firmware to recover it from.
        case recover(Firmware)
        /// None is kept, and the VM folder does not say which firmware it runs.
        case unidentified
    }

    /// The firmware comes from the restore tree name `fw patch` mirrored into
    /// `FirmwareOriginals`, which names exactly the IPSW the boot chain was
    /// built from; `restore-info.json` (`recorded`) answers only when no such
    /// folder is there. Two folders for the device are not guessed between.
    public static func need(
        device: VPhoneGuestDevice,
        in vm: VPhoneConfinedDirectory,
        recorded: VPhoneRestoreInfo.OSVersion?,
    ) throws -> Need {
        guard try kept(in: vm).isEmpty else { return .kept }
        var trees: [String] = []
        if try vm.isDirectory(originalsName) {
            let stash = try vm.directory(originalsName)
            trees = try stash.entries().filter { try stash.isDirectory($0) }
        }
        let named = trees.compactMap { firmware(treeName: $0, device: device) }
        if named.count == 1, let firmware = named.first {
            return .recover(firmware)
        }
        if named.isEmpty, let recorded, !recorded.version.isEmpty, !recorded.build.isEmpty {
            return .recover(Firmware(device: device, version: recorded.version, build: recorded.build))
        }
        return .unidentified
    }

    // MARK: - IPSW

    /// Where a VM's IPSW can be: the shared cache (`~/.vphone/ipsws`, or
    /// `$VPHONE_ROOT/ipsws`), and the `ipsws` folder beside the VM's library,
    /// which is the same cache for a library under another data root.
    public static func searchDirectories(forVirtualMachineAt vm: URL) -> [URL] {
        let beside = vm.standardizedFileURL.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ipsws", isDirectory: true)
        var directories: [URL] = []
        for directory in [VPhoneResources.ipswCacheDirectory(), beside] {
            let path = directory.standardizedFileURL.path
            if !directories.contains(where: { $0.standardizedFileURL.path == path }) {
                directories.append(directory)
            }
        }
        return directories
    }

    public struct Source: Sendable {
        public let archive: URL
        /// The member the BuildManifest names for the board's device tree.
        public let member: String
        public let contents: Data
    }

    /// The first IPSW in `directories`, by name, whose BuildManifest is
    /// `firmware`'s version and build, covers its product type and names a
    /// device tree for its board; with that tree's bytes. Unreadable archives
    /// and partial downloads are passed over.
    public static func find(_ firmware: Firmware, in directories: [URL]) -> Source? {
        let fm = FileManager.default
        for directory in directories {
            let names = ((try? fm.contentsOfDirectory(atPath: directory.path)) ?? [])
                .filter { !$0.hasPrefix(".") && $0.lowercased().hasSuffix(".ipsw") }
                .sorted()
            for name in names {
                let file = directory.appendingPathComponent(name)
                guard let manifest = try? VPhoneIPSWCache.buildManifest(of: file),
                      let member = member(for: firmware, in: manifest),
                      let contents = try? VPhoneArchiveReader.readMember(member, from: file),
                      !contents.isEmpty
                else { continue }
                return Source(archive: file, member: member, contents: contents)
            }
        }
        return nil
    }

    /// The archive path of `firmware`'s board tree, when `manifest` is that
    /// firmware: same version and build, the device among its product types,
    /// and a build identity for the board whose `DeviceTree` is the tree.
    static func member(for firmware: Firmware, in manifest: [String: Any]) -> String? {
        guard manifest["ProductVersion"] as? String == firmware.version,
              manifest["ProductBuildVersion"] as? String == firmware.build,
              VPhoneGuestDevice.covered(by: manifest).contains(firmware.device)
        else { return nil }
        for identity in manifest["BuildIdentities"] as? [[String: Any]] ?? [] {
            let info = identity["Info"] as? [String: Any]
            guard (info?["DeviceClass"] as? String)?.lowercased() == firmware.device.deviceClass else { continue }
            let deviceTree = (identity["Manifest"] as? [String: Any])?["DeviceTree"] as? [String: Any]
            if let path = (deviceTree?["Info"] as? [String: Any])?["Path"] as? String,
               (path as NSString).lastPathComponent == firmware.fileName
            {
                return path
            }
        }
        return nil
    }

    // MARK: - Store

    /// Keep `source` where `fw patch` would have, so every later run finds it
    /// there. Written through the pinned VM folder and renamed into place, so
    /// a link in the folder is replaced rather than written through. Folders
    /// it creates and the file get mode 0777, like every host VM artifact.
    /// Returns the path relative to the VM folder.
    @discardableResult
    public static func store(_ source: Source, for firmware: Firmware, in vm: VPhoneConfinedDirectory) throws -> String {
        let components = (firmware.keptPath as NSString).deletingLastPathComponent.split(separator: "/").map(String.init)
        var directory = vm
        for component in components {
            let existed = try directory.exists(component)
            directory = try directory.directory(component, create: true, mode: 0o777)
            if !existed {
                guard fchmod(directory.descriptor, 0o777) == 0 else {
                    throw VPhoneConfinedDirectoryError.system(component, errno)
                }
            }
        }
        try directory.writeFile(firmware.fileName, contents: source.contents, mode: 0o777)
        return firmware.keptPath
    }
}
