import Darwin
import Foundation

// MARK: - Payload

extension GuestIrisinInstaller {
    static func validatePayload(
        app: URL, daemon: URL, helper: URL, plist: URL,
        version: String, architecture: String, layout: String,
    ) throws {
        let info = NSDictionary(contentsOf: app.appendingPathComponent("Info.plist"))
        guard info?["CFBundleIdentifier"] as? String == "wiki.qaq.irisin",
              info?["CFBundleShortVersionString"] as? String == version,
              info?["IrisinCurrentArchitecture"] as? String == architecture,
              FileManager.default.isExecutableFile(atPath: app.appendingPathComponent("irisin").path),
              FileManager.default.isExecutableFile(atPath: daemon.path),
              FileManager.default.isExecutableFile(atPath: helper.path),
              let properties = NSDictionary(contentsOf: plist) as? [String: Any],
              properties["Label"] as? String == serviceLabel,
              let arguments = properties["ProgramArguments"] as? [String],
              arguments == [layout == "roothide" ? "/usr/libexec/irisind" : rootlessRoot + "/usr/libexec/irisind"]
        else { throw GuestAPIError.operationFailed("Irisin release payload is incomplete or has the wrong layout") }
    }

    /// mobile owns /var/mobile/Documents, so either path component may be a
    /// symlink it planted to have root hand another directory to mobile. Both
    /// are opened without following a link, and ownership is set through the
    /// descriptor rather than the path.
    static func prepareAppData() throws {
        let documents = "/var/mobile/Documents"
        let name = "wiki.qaq.irisin"
        if mkdir(documents, 0o755) != 0, errno != EEXIST {
            throw GuestAPIError.operationFailed("Could not create \(documents): \(String(cString: strerror(errno)))")
        }
        let parent = open(documents, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard parent >= 0 else {
            throw GuestAPIError.operationFailed("\(documents) is not a real directory")
        }
        defer { close(parent) }
        if mkdirat(parent, name, 0o755) != 0, errno != EEXIST {
            throw GuestAPIError.operationFailed("Could not create Irisin app data: \(String(cString: strerror(errno)))")
        }
        var info = stat()
        guard fstatat(parent, name, &info, AT_SYMLINK_NOFOLLOW) == 0,
              info.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR)
        else { throw GuestAPIError.operationFailed("Irisin app data path is not a real directory") }
        let directory = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard directory >= 0 else {
            throw GuestAPIError.operationFailed("Irisin app data path is not a real directory")
        }
        defer { close(directory) }
        guard fchown(directory, 501, 501) == 0, fchmod(directory, 0o755) == 0 else {
            throw GuestAPIError.operationFailed("Could not assign Irisin app data to mobile")
        }
    }

    static func payloadComponents(from payload: URL, to root: URL, app: URL) throws -> [(URL, URL)] {
        let files = FileManager.default
        var components: [(URL, URL)] = []

        func collect(_ source: URL, _ destination: URL) throws {
            var info = stat()
            guard lstat(source.path, &info) == 0 else {
                throw GuestAPIError.operationFailed("Could not inspect Irisin payload: \(source.path)")
            }
            if info.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR), source != app {
                let children = try files.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }
                if children.isEmpty {
                    try files.createDirectory(at: destination, withIntermediateDirectories: true)
                }
                for child in children {
                    try collect(child, destination.appendingPathComponent(child.lastPathComponent))
                }
            } else {
                components.append((source, destination))
            }
        }

        for source in try files.contentsOfDirectory(at: payload, includingPropertiesForKeys: nil)
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            where source.lastPathComponent != "DEBIAN"
        {
            try collect(source, root.appendingPathComponent(source.lastPathComponent))
        }
        return components
    }

    static func replace(_ source: URL, at target: URL) throws -> (target: URL, backup: URL?) {
        let files = FileManager.default
        let parent = target.deletingLastPathComponent()
        try files.createDirectory(at: parent, withIntermediateDirectories: true,
                                  attributes: [.posixPermissions: 0o755])
        let suffix = UUID().uuidString
        let candidate = parent.appendingPathComponent(".\(target.lastPathComponent).vphoned-\(suffix)")
        let backup = parent.appendingPathComponent(".\(target.lastPathComponent).backup-\(suffix)")
        try files.copyItem(at: source, to: candidate)
        var old: URL?
        do {
            if itemExists(target) {
                var info = stat()
                guard lstat(target.path, &info) == 0, info.st_mode & mode_t(S_IFMT) != mode_t(S_IFLNK) else {
                    throw GuestAPIError.operationFailed("Irisin destination is a symlink: \(target.path)")
                }
                try files.moveItem(at: target, to: backup)
                old = backup
            }
            try files.moveItem(at: candidate, to: target)
            return (target, old)
        } catch {
            try? files.removeItem(at: candidate)
            if let old {
                try? files.moveItem(at: old, to: target)
            }
            throw error
        }
    }
}
