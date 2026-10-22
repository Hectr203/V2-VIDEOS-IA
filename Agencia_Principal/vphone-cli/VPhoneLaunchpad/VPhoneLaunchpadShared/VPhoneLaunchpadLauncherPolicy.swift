import Darwin
import Foundation

// MARK: - Refusal

nonisolated struct VPhoneLaunchpadLauncherRefusal: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String {
        message
    }
}

// MARK: - Policy

/// What `vphone-launchpad-launcher` agrees to start. The app checks it to
/// decide whether to go through the launcher; the launcher checks it again
/// because anything on the machine can run it.
///
/// The launcher is attributed to the Developer ID signed app it ships in, so
/// every VM it starts uses the app's privacy permissions (microphone,
/// location). Running any path it was given would let any local
/// process borrow them. It therefore only starts `vm launch` of a `vphone-cli`
/// in the root-owned bundle store, where nobody but root can change what that
/// path runs.
nonisolated enum VPhoneLaunchpadLauncherPolicy {
    static let executableName = "vphone-launchpad-launcher"

    /// The part of the path below a store entry.
    static let executableTail = ["VPhone.bundle", "Contents", "MacOS", "vphone-cli"]

    /// The leading arguments every start must have. Launchpad goes through
    /// the launcher only for commands that outlive it, and that is always
    /// `vm launch`.
    static let requiredArguments = ["vm", "launch"]

    struct FileStatus: Equatable {
        let owner: uid_t
        let mode: mode_t

        var isDirectory: Bool {
            mode & S_IFMT == S_IFDIR
        }

        var isRegularFile: Bool {
            mode & S_IFMT == S_IFREG
        }

        /// Writable by anyone but its owner.
        var isSharedWritable: Bool {
            mode & (S_IWGRP | S_IWOTH) != 0
        }
    }

    typealias Resolve = (String) -> String?
    typealias Status = (String) -> FileStatus?

    /// The executable `path` names once symlinks are followed.
    static func resolvedPath(_ path: String) -> String? {
        guard let resolved = realpath(path, nil) else {
            return nil
        }
        defer { free(resolved) }
        return String(cString: resolved)
    }

    /// `lstat`, so a symlink is never taken for what it points at.
    static func fileStatus(_ path: String) -> FileStatus? {
        var information = stat()
        guard lstat(path, &information) == 0 else {
            return nil
        }
        return FileStatus(owner: information.st_uid, mode: information.st_mode)
    }

    /// The path to execute for `executable` with `arguments`, or a refusal
    /// that says why not. Every directory from the file up to `/` must be
    /// owned by root and writable by nobody else, so the path cannot be
    /// redirected after this check.
    static func check(
        executable: String,
        arguments: [String],
        storeRoot: String = VPhoneLaunchpadBundleStore.root.path,
        resolve: Resolve = resolvedPath,
        status: Status = fileStatus,
    ) throws(VPhoneLaunchpadLauncherRefusal) -> String {
        guard arguments.count > requiredArguments.count,
              Array(arguments.prefix(requiredArguments.count)) == requiredArguments
        else {
            throw VPhoneLaunchpadLauncherRefusal("only `vphone-cli vm launch <machine>` can be started")
        }
        guard let root = resolve(storeRoot) else {
            throw VPhoneLaunchpadLauncherRefusal("the bundle store \(storeRoot) does not exist")
        }
        guard let path = resolve(executable) else {
            throw VPhoneLaunchpadLauncherRefusal("\(executable) does not exist")
        }
        let rootComponents = components(root)
        let pathComponents = components(path)
        guard pathComponents.count == rootComponents.count + 1 + executableTail.count,
              Array(pathComponents.prefix(rootComponents.count)) == rootComponents,
              Array(pathComponents.suffix(executableTail.count)) == executableTail
        else {
            throw VPhoneLaunchpadLauncherRefusal(
                "\(path) is not the vphone-cli of a bundle in \(root)",
            )
        }

        guard let file = status(path), file.isRegularFile else {
            throw VPhoneLaunchpadLauncherRefusal("\(path) is not a regular file")
        }
        try requireRootOnly(path, file)
        for count in stride(from: pathComponents.count - 1, through: 0, by: -1) {
            let directory = "/" + pathComponents.prefix(count).joined(separator: "/")
            guard let entry = status(directory), entry.isDirectory else {
                throw VPhoneLaunchpadLauncherRefusal("\(directory) is not a directory")
            }
            try requireRootOnly(directory, entry)
        }
        return path
    }

    private static func requireRootOnly(
        _ path: String,
        _ entry: FileStatus,
    ) throws(VPhoneLaunchpadLauncherRefusal) {
        guard entry.owner == 0, !entry.isSharedWritable else {
            throw VPhoneLaunchpadLauncherRefusal(
                "\(path) must be owned by root and writable by nobody else",
            )
        }
    }

    private static func components(_ path: String) -> [String] {
        path.split(separator: "/").map(String.init)
    }
}
