import Darwin
import Foundation

// MARK: - Snapshot

/// One saved moment of a machine's guest state, in
/// `<machine>/Snapshots/<name>/`. Not to be confused with
/// `VPhoneAPFSSnapshot`, which renames the guest's own APFS root snapshot
/// inside the disk image.
public struct VPhoneMachineSnapshot: Equatable, Sendable {
    /// The snapshot's folder name, which is not stored in its metadata.
    public let name: String
    public let created: Date
    public let note: String?
    /// The state files copied into the snapshot, by their names in the
    /// machine folder.
    public let files: [String]
    /// State files the machine did not have when the snapshot was taken.
    /// Revert removes them, so the restored set describes the same moment:
    /// a `restore-info.json` written by a later `cfw install` must not
    /// survive a revert to before it.
    public let absentFiles: [String]

    /// `Snapshot.plist`: everything but the name.
    fileprivate struct Metadata: Codable {
        let created: Date
        let note: String?
        let files: [String]
        let absentFiles: [String]

        enum CodingKeys: String, CodingKey {
            case created = "Created"
            case note = "Note"
            case files = "Files"
            case absentFiles = "AbsentFiles"
        }
    }

    fileprivate init(_ metadata: Metadata, name: String) {
        self.name = name
        created = metadata.created
        note = metadata.note
        files = metadata.files
        absentFiles = metadata.absentFiles
    }
}

// MARK: - Snapshots

/// Machine disk snapshots: APFS clones of the files that describe the guest,
/// taken and put back only while the machine is stopped.
///
/// The disk image, `SEPStorage` and `nvram.bin` are one unit. The SEP's
/// anti-replay counters and the xART gigalocker on the disk advance as a pair,
/// so a disk from one moment with a `SEPStorage` from another panics the SEP.
/// Every operation that copies or replaces them first checks
/// `VPhoneBundleActivity.requireStopped`.
///
/// Snapshots are clones, never copies: `clonefile(2)` costs nothing on APFS,
/// and a full copy of a 60 GB image is not what anyone asked for. Off APFS the
/// operation is refused.
///
/// A snapshot directory is the CLI's metadata file and state files, plus
/// whatever else a client put there (Launchpad keeps its `launchpad.json`
/// binding beside them). Unknown files are never read, kept as they are, and
/// removed with the snapshot.
public enum VPhoneMachineSnapshots {
    /// Inside the machine folder. `vm export` leaves it out, and a clone
    /// starts without it.
    public static let directoryName = "Snapshots"
    public static let metadataFileName = "Snapshot.plist"

    // MARK: State files

    /// The disk image, `SEPStorage` and `nvram.bin` are always captured:
    /// `VPhoneBundleActivity.stateFileNames(of:)`. The files below are
    /// captured when present, and recorded as absent otherwise.
    ///
    /// The set is what changes after creation to describe the guest rather
    /// than the machine:
    ///
    /// - `PatchReceipt.plist` records which patches are live in the guest.
    ///   `restore`, `cfw install` and `cfw update-environment` / `update-kernel`
    ///   rewrite it as they put bytes on the disk or in the boot chain.
    /// - `restore-info.json` records the OS restored onto the disk, and its
    ///   variant is how `cfw install` marks the guest bootable (Launchpad's
    ///   "custom firmware installed").
    ///
    /// Left out on purpose:
    ///
    /// - `config.plist`: identity (ECID, MAC), CPU, memory, network and
    ///   settings must survive a revert.
    /// - `launchpad.json`: Launchpad's, which keeps its own copy in the
    ///   snapshot directory.
    /// - `PatchSelection.plist` is what the owner wants, a setting.
    ///   `PatchPlan.plist` and `FirmwareOriginals/` describe the restore tree
    ///   and boot chain `fw patch` built on the host, which a snapshot does
    ///   not carry either; the receipt is what records what the guest runs.
    /// - `udid-prediction.txt` follows the identity; the ROMs are the
    ///   machine's hardware; `.vphoned.signed` is staged at every launch.
    public static let optionalStateFileNames = ["PatchReceipt.plist", "restore-info.json"]

    public static func directory(of bundle: VPhoneBundle) -> URL {
        bundle.url.appendingPathComponent(directoryName, isDirectory: true)
    }

    // MARK: Names

    /// The same rules as a machine name (the staging directories are hidden,
    /// so a name cannot start with `.`), and one plain path component.
    public static func requireValidName(_ name: String) throws {
        guard (try? VPhoneBundleOperations.requireValidName(name)) != nil,
              VPhoneVirtualMachineManifest.isPlainFileName(name)
        else {
            throw VPhoneMachineSnapshotError.invalidName(name)
        }
    }

    /// The folder of an existing snapshot, whether or not its metadata reads.
    public static func folder(named name: String, of bundle: VPhoneBundle) throws -> URL {
        try requireValidName(name)
        let folder = directory(of: bundle).appendingPathComponent(name, isDirectory: true)
        guard isDirectory(folder) else {
            throw VPhoneMachineSnapshotError.notFound(machine: bundle.name, name: name)
        }
        return folder
    }

    // MARK: List

    /// Every snapshot, oldest first. A directory whose metadata cannot be read
    /// is not listed; `delete` still removes it.
    public static func list(of bundle: VPhoneBundle) throws -> [VPhoneMachineSnapshot] {
        let root = directory(of: bundle)
        let fm = FileManager.default
        guard fm.fileExists(atPath: root.path) else { return [] }
        let names = try fm.contentsOfDirectory(atPath: root.path)
        return names
            .filter { !$0.hasPrefix(".") }
            .compactMap { try? readMetadata(named: $0, in: root) }
            .sorted { ($0.created, $0.name) < ($1.created, $1.name) }
    }

    public static func snapshot(named name: String, of bundle: VPhoneBundle) throws -> VPhoneMachineSnapshot {
        _ = try folder(named: name, of: bundle)
        return try readMetadata(named: name, in: directory(of: bundle))
    }

    // MARK: Create

    /// Clones the state files into `Snapshots/<name>/`. The snapshot is built
    /// in a hidden staging directory and renamed into place, so a failure
    /// leaves nothing behind and a listed snapshot is always complete.
    @discardableResult
    public static func create(
        _ name: String,
        note: String? = nil,
        of bundle: VPhoneBundle,
        now: Date = Date(),
    ) throws -> VPhoneMachineSnapshot {
        try requireValidName(name)
        let root = directory(of: bundle)
        let destination = root.appendingPathComponent(name, isDirectory: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            throw VPhoneMachineSnapshotError.alreadyExists(machine: bundle.name, name: name)
        }
        try VPhoneBundleActivity.requireStopped(bundle)

        var files: [String] = []
        var absent: [String] = []
        for file in VPhoneBundleActivity.stateFileNames(of: bundle) {
            guard isRegularFile(bundle.url.appendingPathComponent(file)) else {
                throw VPhoneMachineSnapshotError.missingStateFile(machine: bundle.name, file: file)
            }
            files.append(file)
        }
        for file in optionalStateFileNames {
            if isRegularFile(bundle.url.appendingPathComponent(file)) {
                files.append(file)
            } else {
                absent.append(file)
            }
        }

        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let staging = root.appendingPathComponent(".creating-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: false)
        do {
            for file in files {
                try cloneFile(
                    bundle.url.appendingPathComponent(file),
                    to: staging.appendingPathComponent(file),
                )
            }
            let metadata = VPhoneMachineSnapshot.Metadata(
                created: now,
                note: note.flatMap { $0.isEmpty ? nil : $0 },
                files: files,
                absentFiles: absent,
            )
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .xml
            try encoder.encode(metadata).write(to: staging.appendingPathComponent(metadataFileName))
            try VPhoneHostFilePermissions.makeAccessible(at: staging)
            // Checked again before the snapshot is published: a VM started
            // while the files were cloned may have moved one of them, and the
            // copies would then come from different moments.
            try VPhoneBundleActivity.requireStopped(bundle)
            // Exclusive: a snapshot of the same name made meanwhile is not replaced.
            guard renamex_np(staging.path, destination.path, UInt32(RENAME_EXCL)) == 0 else {
                if errno == EEXIST {
                    throw VPhoneMachineSnapshotError.alreadyExists(machine: bundle.name, name: name)
                }
                throw VPhoneMachineSnapshotError.failed(path: destination.path, reason: currentErrorText())
            }
            try VPhoneHostFilePermissions.makeDirectoryAccessible(at: root)
            return VPhoneMachineSnapshot(metadata, name: name)
        } catch {
            try? fm.removeItem(at: staging)
            removeIfEmpty(root)
            throw error
        }
    }

    // MARK: Revert

    /// Puts the snapshot's state files back over the live ones and keeps the
    /// snapshot.
    ///
    /// Every file is cloned into a hidden directory in the machine folder
    /// first; only when all of them are there does the live set change, by
    /// `rename(2)` on one volume. Each live file is moved aside into that
    /// directory before its snapshot copy takes its place, and a failure
    /// partway puts the moved files back, so the live set is either the old
    /// one or the snapshot's, never a mix.
    @discardableResult
    public static func revert(to name: String, of bundle: VPhoneBundle) throws -> VPhoneMachineSnapshot {
        let snapshot = try snapshot(named: name, of: bundle)
        let source = directory(of: bundle).appendingPathComponent(name, isDirectory: true)
        try requireValidFileLists(of: snapshot, bundle: bundle)
        try VPhoneBundleActivity.requireStopped(bundle)

        let fm = FileManager.default
        let staging = bundle.url.appendingPathComponent(".snapshot-revert-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: staging) }

        for file in snapshot.files {
            let from = source.appendingPathComponent(file)
            guard isRegularFile(from) else {
                throw VPhoneMachineSnapshotError.damaged(
                    name: name,
                    reason: "\(file) is missing from the snapshot",
                )
            }
            try cloneFile(from, to: staging.appendingPathComponent(file))
        }
        try VPhoneHostFilePermissions.makeAccessible(at: staging)

        // Checked again just before the live files change: the clones above
        // take a moment, and nothing may open the machine meanwhile.
        try VPhoneBundleActivity.requireStopped(bundle)
        try replaceLiveFiles(with: snapshot, staged: staging, in: bundle)
        return snapshot
    }

    /// One step of the swap: `file` was moved aside (or did not exist live),
    /// and a snapshot copy may have taken its place.
    private struct SwapStep {
        let file: String
        let movedAside: Bool
        var placed = false
    }

    /// Replaces each live file in `snapshot.files` with its copy in `staging`
    /// and removes each one in `snapshot.absentFiles`. A live file is first
    /// renamed to `staging/old-<name>`, so it is deleted only with the staging
    /// directory once every step has succeeded. On a failure the steps done
    /// are undone in reverse.
    private static func replaceLiveFiles(with snapshot: VPhoneMachineSnapshot, staged staging: URL, in bundle: VPhoneBundle) throws {
        let absent = Set(snapshot.absentFiles)
        var steps: [SwapStep] = []
        do {
            for file in snapshot.files + snapshot.absentFiles {
                let live = bundle.url.appendingPathComponent(file).path
                let aside = staging.appendingPathComponent("old-\(file)").path
                let movedAside = rename(live, aside) == 0
                if !movedAside, errno != ENOENT {
                    throw VPhoneMachineSnapshotError.failed(path: live, reason: currentErrorText())
                }
                steps.append(SwapStep(file: file, movedAside: movedAside))
                if absent.contains(file) {
                    continue
                }
                guard rename(staging.appendingPathComponent(file).path, live) == 0 else {
                    throw VPhoneMachineSnapshotError.failed(path: live, reason: currentErrorText())
                }
                steps[steps.count - 1].placed = true
            }
        } catch {
            let notRestored = undo(steps, staging: staging, bundle: bundle)
            guard notRestored.isEmpty else {
                throw VPhoneMachineSnapshotError.revertIncomplete(
                    machine: bundle.name,
                    reason: "\(error)",
                    files: notRestored,
                )
            }
            throw error
        }
    }

    /// Puts each live file moved aside back, and removes a snapshot copy
    /// placed where there was no live file. Best effort, in reverse; returns
    /// the files it could not put back.
    private static func undo(_ steps: [SwapStep], staging: URL, bundle: VPhoneBundle) -> [String] {
        var notRestored: [String] = []
        for step in steps.reversed() {
            let live = bundle.url.appendingPathComponent(step.file).path
            if step.movedAside {
                // Replaces the placed snapshot copy, if any, in one rename.
                if rename(staging.appendingPathComponent("old-\(step.file)").path, live) != 0 {
                    notRestored.append(step.file)
                }
            } else if step.placed, unlink(live) != 0, errno != ENOENT {
                notRestored.append(step.file)
            }
        }
        return notRestored.reversed()
    }

    // MARK: Delete

    /// Removes the snapshot directory and everything in it. The live state is
    /// not touched, so a running machine does not prevent it.
    public static func delete(_ name: String, of bundle: VPhoneBundle) throws {
        try FileManager.default.removeItem(at: folder(named: name, of: bundle))
        removeIfEmpty(directory(of: bundle))
    }

    // MARK: - Files

    private static func readMetadata(named name: String, in root: URL) throws -> VPhoneMachineSnapshot {
        let url = root.appendingPathComponent(name).appendingPathComponent(metadataFileName)
        do {
            let metadata = try PropertyListDecoder().decode(VPhoneMachineSnapshot.Metadata.self, from: Data(contentsOf: url))
            return VPhoneMachineSnapshot(metadata, name: name)
        } catch {
            throw VPhoneMachineSnapshotError.damaged(name: name, reason: "\(metadataFileName) is unreadable")
        }
    }

    /// Revert replaces every file in `files` and deletes every file in
    /// `absentFiles` in the machine folder, by names read from metadata anyone
    /// can edit. So the lists must name state files only, each once, and
    /// `files` must hold the disk image, `SEPStorage` and `nvram.bin`: a revert
    /// that put back the disk alone would pair it with the live `SEPStorage`.
    private static func requireValidFileLists(of snapshot: VPhoneMachineSnapshot, bundle: VPhoneBundle) throws {
        func damaged(_ reason: String) -> VPhoneMachineSnapshotError {
            .damaged(name: snapshot.name, reason: reason)
        }
        let required = VPhoneBundleActivity.stateFileNames(of: bundle)
        let known = Set(required + optionalStateFileNames)
        let listed = snapshot.files + snapshot.absentFiles
        if let unknown = listed.first(where: { !known.contains($0) }) {
            throw damaged("it names '\(unknown)', which is not a state file")
        }
        if let missing = required.first(where: { !snapshot.files.contains($0) }) {
            throw damaged("it does not hold \(missing), which must be restored with the other state files")
        }
        if let both = snapshot.files.first(where: { snapshot.absentFiles.contains($0) }) {
            throw damaged("it lists \(both) as both captured and absent")
        }
        if Set(listed).count != listed.count {
            throw damaged("it lists a state file more than once")
        }
    }

    /// An APFS clone, never a copy. Symbolic links are not followed.
    private static func cloneFile(_ source: URL, to destination: URL) throws {
        guard clonefile(source.path, destination.path, UInt32(CLONE_NOFOLLOW)) == 0 else {
            let code = errno
            if code == ENOTSUP || code == EXDEV {
                throw VPhoneMachineSnapshotError.notCloneable(path: source.path)
            }
            throw VPhoneMachineSnapshotError.failed(path: source.path, reason: String(cString: strerror(code)))
        }
    }

    private static func isRegularFile(_ url: URL) -> Bool {
        VPhoneVirtualMachineManifest.fileKind(at: url) == .regularFile
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var info = stat()
        return lstat(url.path, &info) == 0 && info.st_mode & S_IFMT == S_IFDIR
    }

    /// `rmdir` only succeeds on an empty directory, which is the point.
    private static func removeIfEmpty(_ url: URL) {
        rmdir(url.path)
    }

    private static func currentErrorText() -> String {
        String(cString: strerror(errno))
    }
}

// MARK: - Error

public enum VPhoneMachineSnapshotError: Error, Equatable {
    case invalidName(String)
    case alreadyExists(machine: String, name: String)
    case notFound(machine: String, name: String)
    case missingStateFile(machine: String, file: String)
    case notCloneable(path: String)
    case damaged(name: String, reason: String)
    case failed(path: String, reason: String)
    /// A revert failed partway and some live files could not be put back.
    case revertIncomplete(machine: String, reason: String, files: [String])
}

extension VPhoneMachineSnapshotError: CustomStringConvertible, LocalizedError {
    public var description: String {
        switch self {
        case let .invalidName(name):
            "Invalid snapshot name '\(name)'. Use a name that is not empty, has no '/', and does not start with '.'."
        case let .alreadyExists(machine, name):
            "VM '\(machine)' already has a snapshot named '\(name)'. Choose a different name."
        case let .notFound(machine, name):
            "VM '\(machine)' has no snapshot named '\(name)'. List them with vm snapshot list."
        case let .missingStateFile(machine, file):
            "VM '\(machine)' has no \(file) yet. Boot it once, then take the snapshot."
        case let .notCloneable(path):
            "Cannot clone \(path): snapshots need the VM on an APFS volume, and a full copy is not made."
        case let .damaged(name, reason):
            "Snapshot '\(name)' is damaged: \(reason). Delete it."
        case let .failed(path, reason):
            "Snapshot operation failed at \(path): \(reason)."
        case let .revertIncomplete(machine, reason, files):
            "Reverting VM '\(machine)' failed (\(reason)), and its previous "
                + "\(files.joined(separator: ", ")) could not be put back. Its state files may be "
                + "inconsistent: revert to a snapshot again before starting it."
        }
    }

    public var errorDescription: String? {
        description
    }
}
