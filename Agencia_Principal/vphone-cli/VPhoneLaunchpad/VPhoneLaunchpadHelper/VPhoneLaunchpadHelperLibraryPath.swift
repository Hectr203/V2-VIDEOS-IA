import Darwin
import Foundation

/// Checks on the library folders a request names, and the environment a
/// root `vphone-cli` child runs with. Shared by every verb that runs the
/// bundle's command line for the caller.
enum VPhoneLaunchpadHelperLibraryPath {
    /// Opens an absolute, canonical directory path one component at a time
    /// from "/", refusing a symbolic link anywhere in it.
    static func openDirectory(_ path: String) throws -> Int32 {
        let components = path.split(separator: "/", omittingEmptySubsequences: false).dropFirst()
        guard path.hasPrefix("/"),
              !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." })
        else {
            throw VPhoneLaunchpadHelperError("The library path \(path) must be an absolute path without . or .. components.")
        }
        var directory = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard directory >= 0 else {
            throw VPhoneLaunchpadHelperError("The library folder \(path) does not exist.")
        }
        for component in components {
            let next = openat(directory, String(component), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            let failure = errno
            close(directory)
            guard next >= 0 else {
                throw VPhoneLaunchpadHelperError(
                    failure == ELOOP || failure == ENOTDIR
                        ? "The library path cannot include symbolic links."
                        : "The library folder \(path) does not exist.",
                )
            }
            directory = next
        }
        return directory
    }

    static func requireOwner(_ descriptor: Int32, _ path: String, _ uid: uid_t) throws {
        var info = stat()
        guard fstat(descriptor, &info) == 0, (info.st_mode & S_IFMT) == S_IFDIR else {
            throw VPhoneLaunchpadHelperError("\(path) is not a folder.")
        }
        guard info.st_uid == uid else {
            throw VPhoneLaunchpadHelperError("\(path) is not owned by your user account.")
        }
    }

    /// The environment `sudo vphone-cli …` sees for the caller. SUDO_UID and
    /// SUDO_GID are how the command line finds the caller's home and hands
    /// root-created files back afterwards.
    static func environment(callerUID: uid_t, callerGID: gid_t) throws -> [String: String] {
        guard let account = getpwuid(callerUID) else {
            throw VPhoneLaunchpadHelperError("Unable to find the user account with ID \(callerUID).")
        }
        let userName = String(cString: account.pointee.pw_name)
        let home = String(cString: account.pointee.pw_dir)
        return [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME": home,
            "USER": userName,
            "LOGNAME": userName,
            "SUDO_USER": userName,
            "SUDO_UID": String(callerUID),
            "SUDO_GID": String(callerGID),
            "LANG": "en_US.UTF-8",
        ]
    }
}
