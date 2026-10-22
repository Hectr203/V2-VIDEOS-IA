import Darwin
import Foundation
import IcliKit
import IcliSystem
import VphonedNative

// MARK: - Removable System Apps

/// `apps.remove_system` removes Apple's removable apps durably;
/// `apps.restore_system` puts them back from the backup it kept, and
/// `apps.removed_system` lists those backups.
///
/// The order is fixed. The whole bundle container is backed up, the app is
/// unregistered from LaunchServices, and only then is the container removed,
/// with its `SerializedPlaceholder.ipa` and metadata. Removing only the `.app`
/// leaves a registered app with a missing bundle, which installd repairs from
/// the placeholder on the next boot; removing the container while the app is
/// still registered does the same. Each app's container path comes from the
/// live app list, since the UUID changes with every install.
/// `GuestSystemAppPolicy` decides which apps qualify;
/// `Research/Guest/post_setup_signin_and_appstore.md` has the measurements.
extension GuestAPI {
    static func executeSystemApps(_ method: String, _ params: [String: Any]) throws -> [String: Any]? {
        switch method {
        case "apps.remove_system":
            guard let ids = try systemAppIDs(params) else {
                throw GuestAPIError.invalidRequest("bundle_ids must list the apps to remove")
            }
            try requireForce(params, "remove \(ids.joined(separator: ", "))")
            return try removeSystemApps(
                ids,
                backup: bool(params, "backup", default: true),
                respring: bool(params, "respring", default: true),
            )
        case "apps.restore_system":
            let ids = try systemAppIDs(params) ?? backedUpSystemAppIDs()
            try requireForce(params, "restore removed system apps")
            return try restoreSystemApps(ids, respring: bool(params, "respring", default: true))
        case "apps.removed_system":
            return removedSystemApps()
        default:
            return nil
        }
    }

    /// `bundle_ids` in request order without repeats, or nil when absent.
    private static func systemAppIDs(_ params: [String: Any]) throws -> [String]? {
        guard let value = params["bundle_ids"] else { return nil }
        guard let ids = value as? [String], !ids.isEmpty, ids.allSatisfy({ !$0.isEmpty }) else {
            throw GuestAPIError.invalidRequest("bundle_ids must be a non-empty list of bundle identifiers")
        }
        var seen = Set<String>()
        return ids.filter { seen.insert($0).inserted }
    }

    // MARK: - Remove

    private static func removeSystemApps(_ ids: [String], backup: Bool, respring restart: Bool) throws -> [String: Any] {
        let results = ids.map { removeSystemApp($0, backup: backup) }
        let changed = results.filter { $0["removed"] as? Bool == true }.count
        let failed = results.filter { $0["status"] as? String == "failed" }.count
        var result: [String: Any] = [
            "results": results,
            "removed": changed,
            "failed": failed,
            "backup_directory": backup ? GuestSystemAppPolicy.backupDirectory : NSNull(),
            "respring": restart && changed > 0 ? respringResult() : NSNull(),
        ]
        guard failed == 0 else {
            result["error"] = "remove_incomplete"
            result["message"] = "\(failed) of \(ids.count) apps were not removed; see results"
            throw IcliError.commandFailed(result)
        }
        return result
    }

    /// One app. Errors land in the result, so one app's failure does not
    /// stop the others.
    private static func removeSystemApp(_ id: String, backup: Bool) -> [String: Any] {
        var result: [String: Any] = ["bundle_id": id, "removed": false]
        do {
            try GuestSystemAppPolicy.validateBundleID(id)
            guard let record = try installedApp(id) else {
                return try finishInterruptedRemoval(id, result: result)
            }
            let bundlePath = record["bundle_path"] as? String ?? ""
            let location = try GuestSystemAppLocation(bundlePath: bundlePath)
            result["bundle_path"] = bundlePath
            result["container"] = location.containerPath
            result["app"] = location.appDirectoryName

            guard try bundleContainerExists(location) else {
                // LaunchServices lists a bundle whose container is gone:
                // dropping the record is all that is left to do.
                let unregistered = try unregisterSystemApp(bundlePath)
                result["unregistered"] = unregistered["unregistered"] as? Bool ?? false
                result["status"] = "unregistered_stale"
                result["removed"] = true
                result["backup"] = NSNull()
                return result
            }
            try checkBundleIdentifier(location, id)

            result["backup"] = NSNull()
            if backup {
                let made = try backUpContainer(id, location)
                result["backup"] = made.path
                result["backup_method"] = made.method
            }
            do {
                let unregistered = try unregisterSystemApp(bundlePath)
                result["unregistered"] = unregistered["unregistered"] as? Bool ?? false
                if let attempts = unregistered["attempts"] as? Int, attempts > 1 {
                    result["unregister_attempts"] = attempts
                }
            } catch {
                if backup {
                    discardBackup(id)
                    result["backup"] = NSNull()
                }
                throw error
            }
            do {
                _ = try removePath(location.containerPath, recursive: true, force: true)
            } catch {
                throw GuestAPIError.operationFailed(
                    "\(id) is unregistered but its container \(location.containerPath) was not removed "
                        + "(\(describe(error))); "
                        + (backup ? "run apps.remove_system again to finish" : "remove it with files.remove"),
                )
            }
            result["status"] = "removed"
            result["removed"] = true
            if backup {
                // The new backup supersedes one an older vphoned left on the
                // User volume.
                discardBackup(id, in: GuestSystemAppPolicy.legacyBackupDirectory)
            }
        } catch {
            result["status"] = "failed"
            result["error"] = describe(error)
        }
        return result
    }

    /// The app is not registered. If an earlier removal unregistered it and
    /// backed it up but stopped before the container was gone, finish it;
    /// otherwise there is nothing to do. A container a failed restore moved
    /// back has no backup beside it and is left alone.
    private static func finishInterruptedRemoval(_ id: String, result: [String: Any]) throws -> [String: Any] {
        var result = result
        result["status"] = "absent"
        result["backup"] = NSNull()
        guard let directory = GuestSystemAppPolicy.backupDirectory(holding: id, exists: pathExists) else { return result }
        let backupPath = GuestSystemAppPolicy.backupContainerPath(id, in: directory)
        result["backup"] = pathExists(backupPath) ? backupPath : NSNull()
        guard pathExists(GuestSystemAppPolicy.manifestPath(id, in: directory)), pathExists(backupPath) else { return result }
        let location = try readManifest(id, in: directory).location()
        guard try bundleContainerExists(location) else { return result }
        try checkBundleIdentifier(location, id)
        _ = try removePath(location.containerPath, recursive: true, force: true)
        result["container"] = location.containerPath
        result["app"] = location.appDirectoryName
        result["status"] = "removed"
        result["removed"] = true
        return result
    }

    /// Clones the whole container to `<bundle_id>.container` in the backup
    /// directory and writes `<bundle_id>.manifest.json` beside it. The backup
    /// directory is on the containers' volume, so the clone shares every block
    /// and costs next to nothing; if the clone fails anyway, a copy that keeps
    /// owners, modes, extended attributes and flags is made instead, and
    /// `method` says which. An older backup of the same app is replaced once
    /// the new one is complete.
    private static func backUpContainer(
        _ id: String,
        _ location: GuestSystemAppLocation,
    ) throws -> (path: String, method: String) {
        let files = FileManager.default
        try prepareBackupDirectory()
        let destination = GuestSystemAppPolicy.backupContainerPath(id)
        let staging = destination + ".partial"
        if pathExists(staging) {
            try files.removeItem(atPath: staging)
        }
        // clonefile keeps owners and modes when root calls it; the container
        // must come back as installd left it.
        var method = "clone"
        if clonefile(location.containerPath, staging, UInt32(CLONE_NOFOLLOW)) != 0 {
            let reason = String(cString: strerror(errno))
            if pathExists(staging) {
                try? files.removeItem(atPath: staging)
            }
            if let copyFailure = preservingCopy(location.containerPath, to: staging) {
                try? files.removeItem(atPath: staging)
                throw GuestAPIError.operationFailed(
                    "Could not back up \(location.containerPath): clone failed (\(reason)), copy failed (\(copyFailure))",
                )
            }
            method = "copy"
        }
        if pathExists(destination) {
            try files.removeItem(atPath: destination)
        }
        guard rename(staging, destination) == 0 else {
            let reason = String(cString: strerror(errno))
            try? files.removeItem(atPath: staging)
            throw GuestAPIError.operationFailed("Could not move the backup into place: \(reason)")
        }
        let manifest = GuestSystemAppManifest(bundleID: id, location: location, removedAt: Date())
        do {
            try manifest.encoded().write(
                to: URL(fileURLWithPath: GuestSystemAppPolicy.manifestPath(id)),
                options: .atomic,
            )
        } catch {
            try? files.removeItem(atPath: destination)
            throw GuestAPIError.operationFailed("Could not write the backup manifest: \(describe(error))")
        }
        return (destination, method)
    }

    /// `/private/var/db/vphoned/removed-system-apps`, root's alone: mode 0700,
    /// and a real directory, not a link somebody left in its place.
    private static func prepareBackupDirectory() throws {
        let directory = GuestSystemAppPolicy.backupDirectory
        try FileManager.default.createDirectory(
            atPath: (directory as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o755],
        )
        if mkdir(directory, 0o700) != 0, errno != EEXIST {
            throw GuestAPIError.operationFailed("Could not create \(directory): \(String(cString: strerror(errno)))")
        }
        var info = stat()
        guard lstat(directory, &info) == 0, info.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR), info.st_uid == 0 else {
            throw GuestAPIError.operationFailed("\(directory) is not a directory owned by root")
        }
        if info.st_mode & 0o777 != 0o700 {
            _ = chmod(directory, 0o700)
        }
    }

    /// Copies a directory tree as it is: owners, modes, extended attributes,
    /// flags and links. Returns why it failed, or nil.
    private static func preservingCopy(_ source: String, to destination: String) -> String? {
        let flags = copyfile_flags_t(COPYFILE_ALL | COPYFILE_RECURSIVE | COPYFILE_NOFOLLOW)
        guard copyfile(source, destination, nil, flags) == 0 else {
            return String(cString: strerror(errno))
        }
        return nil
    }

    private static func discardBackup(_ id: String, in directory: String = GuestSystemAppPolicy.backupDirectory) {
        try? FileManager.default.removeItem(atPath: GuestSystemAppPolicy.backupContainerPath(id, in: directory))
        try? FileManager.default.removeItem(atPath: GuestSystemAppPolicy.manifestPath(id, in: directory))
    }

    // MARK: - Restore

    private static func restoreSystemApps(_ ids: [String], respring restart: Bool) throws -> [String: Any] {
        let results = ids.map(restoreSystemApp)
        let changed = results.filter { $0["restored"] as? Bool == true }.count
        let failed = results.filter { $0["status"] as? String == "failed" }.count
        var result: [String: Any] = [
            "results": results,
            "restored": changed,
            "failed": failed,
            "respring": restart && changed > 0 ? respringResult() : NSNull(),
        ]
        guard failed == 0 else {
            result["error"] = "restore_incomplete"
            result["message"] = "\(failed) of \(ids.count) apps were not restored; see results"
            throw IcliError.commandFailed(result)
        }
        return result
    }

    /// Moves the backup container back to its original UUID path and
    /// registers the app in it. A backup in the backup directory goes back by
    /// rename; one in the legacy directory is on the User volume and is copied
    /// back with owners, modes, extended attributes and flags, then removed.
    /// The manifest stays until LaunchServices lists the app, so a restore
    /// that moved the container but could not register it is finished by
    /// running it again.
    private static func restoreSystemApp(_ id: String) -> [String: Any] {
        var result: [String: Any] = ["bundle_id": id, "restored": false]
        do {
            try GuestSystemAppPolicy.validateBundleID(id)
            let directory = GuestSystemAppPolicy.backupDirectory(holding: id, exists: pathExists)
            guard let directory, pathExists(GuestSystemAppPolicy.manifestPath(id, in: directory)) else {
                if let record = try installedApp(id) {
                    result["status"] = "present"
                    result["bundle_path"] = record["bundle_path"] ?? ""
                    return result
                }
                throw GuestAPIError.operationFailed(
                    directory.map { "\(GuestSystemAppPolicy.backupContainerPath(id, in: $0)) has no manifest naming its original container" }
                        ?? "No backup of \(id) in \(GuestSystemAppPolicy.backupDirectories.joined(separator: " or "))",
                )
            }
            let backupPath = GuestSystemAppPolicy.backupContainerPath(id, in: directory)
            result["backup"] = backupPath
            result["legacy"] = GuestSystemAppPolicy.isLegacy(directory)
            let location = try readManifest(id, in: directory).location()
            result["container"] = location.containerPath
            result["app"] = location.appDirectoryName
            if let record = try installedApp(id) {
                result["status"] = "present"
                result["bundle_path"] = record["bundle_path"] ?? ""
                result["message"] = "\(id) is installed; the backup was left in place"
                return result
            }
            if pathExists(backupPath) {
                guard !pathExists(location.containerPath) else {
                    throw GuestAPIError.operationFailed("\(location.containerPath) already exists; the backup was left in place")
                }
                let moved = try moveBack(backupPath, to: location.containerPath)
                result["restore_method"] = moved.method
                if let warning = moved.warning {
                    result["warning"] = warning
                }
            } else {
                guard try bundleContainerExists(location) else {
                    throw GuestAPIError.operationFailed("The backup container \(backupPath) is missing")
                }
            }
            try checkBundleIdentifier(location, id)

            var method: UnsafeMutablePointer<CChar>?
            if let error = vp_ls_register_system_app(location.appPath, location.containerPath, &method) {
                defer { free(error) }
                throw GuestAPIError.operationFailed(
                    "\(String(cString: error)); the container is back at \(location.containerPath), "
                        + "run apps.restore_system again to retry the registration",
                )
            }
            defer { free(method) }
            let registration = try appRegistration(location.appPath)
            guard registration["registered"] as? Bool == true else {
                throw GuestAPIError.operationFailed("LaunchServices does not list \(location.appPath) after registration")
            }
            try? FileManager.default.removeItem(atPath: GuestSystemAppPolicy.manifestPath(id, in: directory))
            result["registration"] = method.map { String(cString: $0) } ?? ""
            result["status"] = "restored"
            result["restored"] = true
        } catch {
            result["status"] = "failed"
            result["error"] = describe(error)
        }
        return result
    }

    /// Puts a backup container back at `destination`. A rename on the same
    /// volume; across volumes (EXDEV) a preserving copy to a staging name
    /// beside the destination, a rename into place, then the source removed.
    private static func moveBack(_ source: String, to destination: String) throws -> (method: String, warning: String?) {
        var info = stat()
        guard lstat(source, &info) == 0, info.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR) else {
            throw GuestAPIError.operationFailed("\(source) is not a backup container directory")
        }
        if rename(source, destination) == 0 {
            return ("rename", nil)
        }
        let code = errno
        guard GuestSystemAppPolicy.restoreCopiesAcrossVolumes(renameErrno: code) else {
            throw GuestAPIError.operationFailed("Could not move \(source) back: \(String(cString: strerror(code)))")
        }
        let files = FileManager.default
        let staging = destination + ".partial"
        if pathExists(staging) {
            try files.removeItem(atPath: staging)
        }
        if let failure = preservingCopy(source, to: staging) {
            try? files.removeItem(atPath: staging)
            throw GuestAPIError.operationFailed("Could not copy \(source) back across volumes: \(failure)")
        }
        guard rename(staging, destination) == 0 else {
            let reason = String(cString: strerror(errno))
            try? files.removeItem(atPath: staging)
            throw GuestAPIError.operationFailed("Could not move the copy of \(source) into place: \(reason)")
        }
        do {
            try files.removeItem(atPath: source)
        } catch {
            return ("copy", "The container is back, but \(source) was not removed: \(describe(error))")
        }
        return ("copy", nil)
    }

    // MARK: - Backups

    /// Every app with a backup or a manifest in either backup directory.
    private static func backedUpSystemAppIDs() -> [String] {
        let names = GuestSystemAppPolicy.backupDirectories.flatMap(directoryEntries)
        return Set(names.compactMap(GuestSystemAppPolicy.bundleID(forBackupEntry:))).sorted()
    }

    private static func directoryEntries(_ directory: String) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
    }

    /// The backups in the backup directory, then those an older vphoned left
    /// in the legacy directory, each marked `legacy`.
    private static func removedSystemApps() -> [String: Any] {
        var backups: [[String: Any]] = []
        for directory in GuestSystemAppPolicy.backupDirectories {
            let ids = Set(directoryEntries(directory).compactMap(GuestSystemAppPolicy.bundleID(forBackupEntry:))).sorted()
            for id in ids {
                let backupPath = GuestSystemAppPolicy.backupContainerPath(id, in: directory)
                var entry: [String: Any] = [
                    "bundle_id": id,
                    "backup": pathExists(backupPath) ? backupPath : NSNull(),
                    "legacy": GuestSystemAppPolicy.isLegacy(directory),
                ]
                do {
                    let manifest = try readManifest(id, in: directory)
                    let location = try manifest.location()
                    entry["container"] = location.containerPath
                    entry["container_uuid"] = location.containerUUID
                    entry["app"] = location.appDirectoryName
                    entry["removed_at"] = ISO8601DateFormatter().string(from: manifest.removedAt)
                    entry["restorable"] = pathExists(backupPath) || pathExists(location.containerPath)
                } catch {
                    entry["restorable"] = false
                    entry["error"] = describe(error)
                }
                backups.append(entry)
            }
        }
        // Backups made by hand before this verb existed (`News.container`)
        // name no bundle identifier and have no manifest.
        func other(_ directory: String) -> [String] {
            directoryEntries(directory).filter { GuestSystemAppPolicy.bundleID(forBackupEntry: $0) == nil }.sorted()
        }
        return [
            "directory": GuestSystemAppPolicy.backupDirectory,
            "legacy_directory": GuestSystemAppPolicy.legacyBackupDirectory,
            "backups": backups,
            "other": other(GuestSystemAppPolicy.backupDirectory),
            "legacy_other": other(GuestSystemAppPolicy.legacyBackupDirectory),
        ]
    }

    private static func readManifest(_ id: String, in directory: String) throws -> GuestSystemAppManifest {
        let path = GuestSystemAppPolicy.manifestPath(id, in: directory)
        var info = stat()
        guard lstat(path, &info) == 0, info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG), info.st_size <= 64 * 1024 else {
            throw GuestAPIError.operationFailed("\(path) is not a manifest file")
        }
        return try GuestSystemAppManifest.decode(Data(contentsOf: URL(fileURLWithPath: path)), expectedBundleID: id)
    }

    // MARK: - Helpers

    /// Unregisters the app at `path` and waits for LaunchServices to drop its
    /// record, unregistering once more if it does not
    /// (`GuestAppUnregistration`). IcliKit's `unregisterApp` looks at the
    /// record straight away, and its "still lists the app" is not the last
    /// word. Throws when the app is still listed after the last attempt.
    private static func unregisterSystemApp(_ path: String) throws -> [String: Any] {
        var attempt = 1
        while true {
            var result: [String: Any] = [:]
            var failure: Error?
            do {
                result = try unregisterApp(path, force: true)
            } catch {
                failure = error
            }
            let start = Date()
            polling: while true {
                let registered = try appRegistration(path)["registered"] as? Bool == true
                switch GuestAppUnregistration.next(registered: registered, attempt: attempt, waited: Date().timeIntervalSince(start)) {
                case .done:
                    if failure != nil || attempt > 1 {
                        // Gone, though not when IcliKit looked, or gone
                        // between the last look and the retry.
                        result = ["unregistered": true, "path": path]
                    }
                    result["attempts"] = attempt
                    return result
                case .wait:
                    Thread.sleep(forTimeInterval: GuestAppUnregistration.pollInterval)
                case .retry:
                    attempt += 1
                    break polling
                case .fail:
                    let reason = failure.map(describe) ?? "LaunchServices still lists \(path) after unregistration"
                    throw GuestAPIError.operationFailed(
                        "\(reason) (unregistered \(attempt) times, still listed "
                            + "\(GuestAppUnregistration.settleTimeout) s after the last)",
                    )
                }
            }
        }
    }

    /// The live LaunchServices record for `id`, never a cached one.
    private static func installedApp(_ id: String) throws -> [String: Any]? {
        let apps = try listApps()["apps"] as? [[String: Any]] ?? []
        return apps.first { $0["bundle_id"] as? String == id }
    }

    /// False when the container is gone. A container that is a symbolic link,
    /// not a directory, or resolves elsewhere is refused.
    private static func bundleContainerExists(_ location: GuestSystemAppLocation) throws -> Bool {
        var info = stat()
        guard lstat(location.containerPath, &info) == 0 else { return false }
        guard info.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR),
              let resolved = realpath(location.containerPath, nil)
        else {
            throw GuestAPIError.operationFailed("\(location.containerPath) is not a bundle container directory")
        }
        defer { free(resolved) }
        guard String(cString: resolved) == location.containerPath else {
            throw GuestAPIError.operationFailed("\(location.containerPath) resolves to \(String(cString: resolved))")
        }
        return true
    }

    /// The bundle on disk must be the app asked for, not whatever a stale
    /// record or a hand-edited manifest points at.
    private static func checkBundleIdentifier(_ location: GuestSystemAppLocation, _ id: String) throws {
        var info = stat()
        guard lstat(location.appPath, &info) == 0, info.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR) else {
            throw GuestAPIError.operationFailed("\(location.appPath) is not an app bundle")
        }
        let plist = NSDictionary(contentsOfFile: location.appPath + "/Info.plist")
        guard let found = plist?["CFBundleIdentifier"] as? String else {
            throw GuestAPIError.operationFailed("\(location.appPath) has no readable Info.plist")
        }
        guard found == id else {
            throw GuestAPIError.operationFailed("\(location.appPath) is \(found), not \(id)")
        }
    }

    private static func pathExists(_ path: String) -> Bool {
        var info = stat()
        return lstat(path, &info) == 0
    }

    private static func respringResult() -> Any {
        do {
            return try respring()
        } catch {
            return ["error": describe(error)]
        }
    }

    private static func describe(_ error: Error) -> String {
        switch error {
        case let error as IcliError: error.message
        case let error as GuestAPIError: error.description
        case let error as GuestSystemAppPolicyError: error.description
        default: (error as NSError).localizedDescription
        }
    }
}
