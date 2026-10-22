import Darwin
import Foundation

/// A validated `vphone-cli cfw install` or `cfw update-environment`
/// invocation. Built only from a store bundle whose cdhash still matches its
/// receipt, and only for a VM directory the calling user owns.
struct VPhoneLaunchpadHelperFirmwareRequest {
    enum Operation {
        /// The full install, which needs the prepared restore tree.
        case install(keepArtifacts: Bool)
        /// Redeploys the bundle's guest resources into a stopped machine and
        /// nothing else.
        case updateEnvironment
        /// Swaps the Preboot kernelcache for the re-patched one, keeping data.
        case updateKernel
    }

    typealias MachineKey = VPhoneLaunchpadHelperFirmwareAdmission.MachineKey

    /// CFW keeps its scratch files beside the VM when that VM is on a mounted
    /// external volume. The child directory is root-owned and private. Internal
    /// libraries retain the system temporary directory.
    static let defaultWorkParent = "/private/var/tmp"

    let executable: URL
    let arguments: [String]
    let environment: [String: String]
    let workingDirectory: URL
    let machineKey: MachineKey
    /// The volumes the run writes to, by device, each with a path on it: the
    /// machine folder's and the work parent's. One entry when they share one.
    let volumes: [dev_t: String]

    init(
        operation: Operation,
        bundleVersion: String,
        machineName: String,
        libraryRoot: String,
        callerUID: uid_t,
        callerGID: gid_t,
    ) throws {
        guard VPhoneLaunchpadNames.isCompatibleBundleVersion(bundleVersion) else {
            throw VPhoneLaunchpadHelperError("VPhone.bundle \(bundleVersion) is not supported. Use \(VPhoneLaunchpadNames.minimumBundleVersion) or newer.")
        }
        guard let receipt = VPhoneLaunchpadBundleReceipt.load(version: bundleVersion) else {
            throw VPhoneLaunchpadHelperError("VPhone.bundle \(bundleVersion) is not installed. Install it in Core Bundle, then try again.")
        }
        let executable = VPhoneLaunchpadBundleStore.executable(version: bundleVersion, named: "vphone-cli")
        try VPhoneLaunchpadHelperCodeCheck.requireCDHash(executable, receipt.cdhashes["vphone-cli"])

        guard VPhoneLaunchpadNames.isValidMachineName(machineName) else {
            throw VPhoneLaunchpadHelperError("\"\(machineName)\" is not a valid machine name.")
        }
        // Checked by walking the path from "/" without following any link:
        // the library folder, the machine folder and its Disk.img must belong
        // to the caller. The caller can still rename these afterwards, so this
        // only refuses a bad request up front; the root vphone-cli child pins
        // the machine directory again itself before it touches anything.
        let folder = try Self.requireMachine(libraryRoot: libraryRoot, machineName: machineName, ownedBy: callerUID)
        let machine = URL(fileURLWithPath: libraryRoot, isDirectory: true)
            .appendingPathComponent(machineName, isDirectory: true)
        let workParent = try Self.resolveWorkParent(
            libraryRoot: libraryRoot,
            callerUID: callerUID,
            callerGID: callerGID,
        )
        var work = stat()
        guard stat(workParent, &work) == 0 else {
            throw VPhoneLaunchpadHelperError("Unable to read \(workParent): \(String(cString: strerror(errno)))")
        }

        var arguments: [String]
        switch operation {
        case let .install(keepArtifacts):
            arguments = ["cfw", "install", machineName, "--library-root", libraryRoot,
                         "--work-parent", workParent]
            if keepArtifacts {
                arguments.append("--keep-artifacts")
            }
        case .updateEnvironment:
            arguments = ["cfw", "update-environment", machineName, "--library-root", libraryRoot,
                         "--work-parent", workParent]
        case .updateKernel:
            arguments = ["cfw", "update-kernel", machineName, "--library-root", libraryRoot,
                         "--work-parent", workParent]
        }

        self.executable = executable
        self.arguments = arguments
        workingDirectory = machine
        machineKey = MachineKey(device: folder.st_dev, inode: folder.st_ino)
        // Not one literal: equal keys in a dictionary literal trap.
        var volumes = [work.st_dev: workParent]
        volumes[folder.st_dev] = machine.path
        self.volumes = volumes
        // The same environment `sudo vphone-cli cfw install` sees: SUDO_UID
        // and SUDO_GID are how the installer hands root-created files back
        // to the user afterwards.
        environment = try VPhoneLaunchpadHelperLibraryPath.environment(callerUID: callerUID, callerGID: callerGID)
    }

    /// Selects a protected scratch directory on the VM's mounted external
    /// volume. A user-writable volume root is refused: root must not create a
    /// directory where the caller can race or replace it.
    private static func resolveWorkParent(
        libraryRoot: String,
        callerUID: uid_t,
        callerGID: gid_t,
    ) throws -> String {
        let library = try VPhoneLaunchpadHelperLibraryPath.openDirectory(libraryRoot)
        defer { close(library) }
        var filesystem = statfs()
        guard fstatfs(library, &filesystem) == 0 else {
            throw VPhoneLaunchpadHelperError("Unable to determine the VM library's volume.")
        }
        let mountPoint = withUnsafePointer(to: &filesystem.f_mntonname) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
        }
        guard mountPoint.hasPrefix("/Volumes/"), mountPoint != "/Volumes" else {
            return defaultWorkParent
        }

        let volume = try VPhoneLaunchpadHelperLibraryPath.openDirectory(mountPoint)
        defer { close(volume) }
        var volumeInfo = stat()
        guard fstat(volume, &volumeInfo) == 0, volumeInfo.st_uid == 0 else {
            throw VPhoneLaunchpadHelperError("The external volume root must be owned by root before CFW can use it for temporary files.")
        }
        guard try !callerCanWrite(volumeInfo, callerUID: callerUID, callerGID: callerGID) else {
            throw VPhoneLaunchpadHelperError("The external volume root is writable by your account; refusing to place privileged CFW temporary files there.")
        }

        let leaf = ".vphone-cfw-work"
        if mkdirat(volume, leaf, 0o700) != 0, errno != EEXIST {
            throw VPhoneLaunchpadHelperError("Unable to create the CFW work directory on \(mountPoint): \(String(cString: strerror(errno)))")
        }
        let work = openat(volume, leaf, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard work >= 0 else {
            throw VPhoneLaunchpadHelperError("The CFW work directory on \(mountPoint) is not a real directory.")
        }
        defer { close(work) }
        var workInfo = stat()
        guard fstat(work, &workInfo) == 0,
              workInfo.st_uid == 0,
              (workInfo.st_mode & S_IFMT) == S_IFDIR,
              (workInfo.st_mode & 0o077) == 0
        else {
            throw VPhoneLaunchpadHelperError("\(mountPoint)/\(leaf) must be a root-owned private directory.")
        }
        return mountPoint + "/" + leaf
    }

    private static func callerCanWrite(
        _ directory: stat,
        callerUID: uid_t,
        callerGID: gid_t,
    ) throws -> Bool {
        let mode = directory.st_mode & 0o777
        if callerUID == directory.st_uid {
            return mode & 0o200 != 0
        }
        guard let account = getpwuid(callerUID) else {
            throw VPhoneLaunchpadHelperError("Unable to find the user account for the CFW request.")
        }
        var groups = [Int32](repeating: 0, count: 256)
        var count = Int32(groups.count)
        let found = String(cString: account.pointee.pw_name).withCString {
            getgrouplist($0, Int32(callerGID), &groups, &count)
        }
        guard found >= 0 else {
            throw VPhoneLaunchpadHelperError("Unable to check permissions on the external volume root.")
        }
        if groups.prefix(Int(count)).contains(Int32(directory.st_gid)) {
            return mode & 0o020 != 0
        }
        return mode & 0o002 != 0
    }

    /// The machine a cancel names. It checks no ownership: the operation
    /// found under the key is stopped only for the user who started it.
    static func machineKey(libraryRoot: String, machineName: String) throws -> MachineKey {
        guard VPhoneLaunchpadNames.isValidMachineName(machineName) else {
            throw VPhoneLaunchpadHelperError("\"\(machineName)\" is not a valid machine name.")
        }
        let root = try VPhoneLaunchpadHelperLibraryPath.openDirectory(libraryRoot)
        defer { close(root) }
        let machine = try openMachine(root, libraryRoot: libraryRoot, machineName: machineName)
        defer { close(machine) }
        var folder = stat()
        guard fstat(machine, &folder) == 0 else {
            throw VPhoneLaunchpadHelperError("\(libraryRoot)/\(machineName) is not a folder.")
        }
        return MachineKey(device: folder.st_dev, inode: folder.st_ino)
    }

    // MARK: - Machine directory

    /// Returns the machine folder's metadata.
    private static func requireMachine(libraryRoot: String, machineName: String, ownedBy uid: uid_t) throws -> stat {
        let root = try VPhoneLaunchpadHelperLibraryPath.openDirectory(libraryRoot)
        defer { close(root) }
        try VPhoneLaunchpadHelperLibraryPath.requireOwner(root, libraryRoot, uid)

        let machinePath = libraryRoot + "/" + machineName
        let machine = try openMachine(root, libraryRoot: libraryRoot, machineName: machineName)
        defer { close(machine) }
        try VPhoneLaunchpadHelperLibraryPath.requireOwner(machine, machinePath, uid)

        var disk = stat()
        guard fstatat(machine, "Disk.img", &disk, AT_SYMLINK_NOFOLLOW) == 0,
              (disk.st_mode & S_IFMT) == S_IFREG,
              disk.st_nlink == 1
        else {
            throw VPhoneLaunchpadHelperError("\(machinePath)/Disk.img must be a regular file, not a link.")
        }
        guard disk.st_uid == uid else {
            throw VPhoneLaunchpadHelperError("\(machinePath)/Disk.img is not owned by your user account.")
        }
        var folder = stat()
        guard fstat(machine, &folder) == 0 else {
            throw VPhoneLaunchpadHelperError("\(machinePath) is not a folder.")
        }
        return folder
    }

    private static func openMachine(_ root: Int32, libraryRoot: String, machineName: String) throws -> Int32 {
        let machine = openat(root, machineName, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard machine >= 0 else {
            throw VPhoneLaunchpadHelperError("\(libraryRoot)/\(machineName) is not a folder, or is a symbolic link.")
        }
        return machine
    }
}
