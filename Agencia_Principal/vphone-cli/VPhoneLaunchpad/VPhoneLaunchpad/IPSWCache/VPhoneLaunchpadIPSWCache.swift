import Foundation
import Synchronization

// MARK: - Files

/// One file in an IPSW cache: a downloaded IPSW, or the partial file of a
/// download in progress.
nonisolated struct VPhoneLaunchpadIPSWFile: Identifiable, Hashable, Sendable {
    var url: URL
    /// The name the file will have; for a download in progress, the name it
    /// gets once it finishes.
    var name: String
    var size: Int64
    /// Read from the manifest, else guessed from the name; nil when neither works.
    var facts: VPhoneLaunchpadIPSW?
    var isDownloading: Bool

    var id: String {
        url.path
    }
}

// MARK: - Cache

/// The IPSW caches `fw prepare` downloads into, read and pruned off the main
/// actor. Reading follows no symbolic link, and deleting takes only a
/// regular file with an IPSW's or a partial download's name.
nonisolated enum VPhoneLaunchpadIPSWCache {
    struct Scan: Sendable {
        var cacheDirectories: [URL] = []
        var ipsws: [VPhoneLaunchpadIPSWFile] = []
        /// Each machine folder's guest product type, by folder path.
        var productTypes: [String: String] = [:]
    }

    /// `$VPHONE_ROOT/ipsws`, else `~/.vphone/ipsws`: where `fw prepare`
    /// downloads (`VPhoneResources.ipswCacheDirectory()`).
    static var sharedDirectory: URL {
        let environment = ProcessInfo.processInfo.environment["VPHONE_ROOT"].flatMap { $0.isEmpty ? nil : $0 }
        let root = environment.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".vphone", isDirectory: true)
        return root.appendingPathComponent("ipsws", isDirectory: true)
    }

    /// The shared cache, then the `ipsws` folder beside each library that has
    /// one, as `VPhoneBoardDeviceTree.searchDirectories` looks.
    static func cacheDirectories(libraryRoots: [String]) -> [URL] {
        var directories = [sharedDirectory]
        for root in libraryRoots {
            let beside = URL(fileURLWithPath: root, isDirectory: true)
                .deletingLastPathComponent()
                .appendingPathComponent("ipsws", isDirectory: true)
            let path = beside.standardizedFileURL.path
            guard !directories.contains(where: { $0.standardizedFileURL.path == path }),
                  isDirectory(beside)
            else {
                continue
            }
            directories.append(beside)
        }
        return directories
    }

    /// Every cache's IPSWs, and the product type of each machine in
    /// `machineFolders`, for matching an IPSW to the machines restored from it.
    @concurrent
    static func scan(libraryRoots: [String], machineFolders: [URL]) async throws -> Scan {
        var scan = Scan()
        scan.cacheDirectories = cacheDirectories(libraryRoots: libraryRoots)
        for directory in scan.cacheDirectories {
            scan.ipsws += try ipsws(in: directory)
        }
        for folder in machineFolders {
            try Task.checkCancellation()
            scan.productTypes[folder.path] = guestProductType(in: folder)
        }
        return scan
    }

    // MARK: IPSWs

    private struct ManifestKey: Hashable {
        var path: String
        var size: Int64
        var modified: Date?
    }

    /// Manifests already read, by path, size and modification date, so
    /// opening the list again reads only the directory.
    private static let manifests = Mutex<[ManifestKey: VPhoneLaunchpadIPSW?]>([:])

    static func ipsws(in directory: URL) throws -> [VPhoneLaunchpadIPSWFile] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        var files: [VPhoneLaunchpadIPSWFile] = []
        for name in names.sorted() {
            try Task.checkCancellation()
            let partial = VPhoneLaunchpadIPSW.finalName(ofPartial: name)
            guard partial != nil || isIPSWName(name) else {
                continue
            }
            let url = directory.appendingPathComponent(name, isDirectory: false)
            // A symbolic link reports isRegularFile false: it is not followed.
            guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true else {
                continue
            }
            let size = Int64(values.fileSize ?? 0)
            let facts: VPhoneLaunchpadIPSW? = if let partial {
                VPhoneLaunchpadIPSW(fileName: partial)
            } else {
                manifestFacts(url, size: size, modified: values.contentModificationDate)
                    ?? VPhoneLaunchpadIPSW(fileName: name)
            }
            files.append(VPhoneLaunchpadIPSWFile(
                url: url,
                name: partial ?? name,
                size: size,
                facts: facts,
                isDownloading: partial != nil,
            ))
        }
        return files
    }

    /// `*.ipsw`, not hidden. A partial download is hidden.
    static func isIPSWName(_ name: String) -> Bool {
        !name.hasPrefix(".") && name.lowercased().hasSuffix(".ipsw")
    }

    private static func manifestFacts(_ url: URL, size: Int64, modified: Date?) -> VPhoneLaunchpadIPSW? {
        let key = ManifestKey(path: url.path, size: size, modified: modified)
        if let known = manifests.withLock({ $0[key] }) {
            return known
        }
        let facts = try? VPhoneLaunchpadIPSW.read(url)
        manifests.withLock { $0[key] = .some(facts) }
        return facts
    }

    // MARK: Machines

    /// config.plist's `guestProductType`, else the product type in the name
    /// of the restore tree kept in `FirmwareOriginals`. An iPhone machine of
    /// the default model records none in config.plist.
    static func guestProductType(in folder: URL) -> String? {
        let config = NSDictionary(contentsOf: folder.appendingPathComponent("config.plist"))
        if let type = config?["guestProductType"] as? String, !type.isEmpty {
            return type
        }
        let originals = folder.appendingPathComponent("FirmwareOriginals", isDirectory: true)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: originals.path)) ?? []
        // `fw prepare`'s restore tree: `iPhone17,3_…_Restore`, or for an iPad
        // `iPhoneOS_iPad16,1_…_Restore`.
        for name in names.sorted() where name.hasPrefix("iPhone") && name.hasSuffix("_Restore") {
            if let type = VPhoneLaunchpadIPSW(fileName: name)?.productTypes.first {
                return type
            }
        }
        return nil
    }

    static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    // MARK: Removal

    enum RemovalError: LocalizedError {
        case notIPSW(String)

        var errorDescription: String? {
            switch self {
            case let .notIPSW(name): String(localized: "\(name) is not an IPSW in the IPSW cache.")
            }
        }
    }

    /// Deletes one IPSW, or the partial file of a download, only while it is
    /// still a regular file directly inside one of `cacheDirectories` with an
    /// IPSW's or a partial download's name. A symbolic link is refused, not
    /// followed.
    @concurrent
    static func removeIPSW(_ url: URL, cacheDirectories: [URL]) async throws {
        let name = url.lastPathComponent
        let folder = url.deletingLastPathComponent().standardizedFileURL.path
        guard isIPSWName(name) || VPhoneLaunchpadIPSW.finalName(ofPartial: name) != nil,
              cacheDirectories.contains(where: { $0.standardizedFileURL.path == folder })
        else {
            throw RemovalError.notIPSW(name)
        }
        // Read now, not from the URL's cached resource values: the file may
        // have changed since the list was read. The attributes are lstat's,
        // so a symbolic link reports itself instead of its target.
        let type = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.type] as? FileAttributeType
        guard type == .typeRegular else {
            throw RemovalError.notIPSW(name)
        }
        try FileManager.default.removeItem(at: url)
    }
}
