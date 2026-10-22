import Darwin
import Foundation

// Checks the guest-free rules behind apps.remove_system, apps.restore_system
// and apfs.snapshot.delete: GuestSystemAppPolicy.swift and
// GuestSnapshotPolicy.swift, compiled for the Mac by
// run-system-maintenance-tests.sh. Nothing here touches a file system.

@main
enum SystemMaintenanceTests {
    nonisolated(unsafe) static var failures = 0
    nonisolated(unsafe) static var checks = 0

    static func check(_ condition: Bool, _ message: String, line: Int = #line) {
        checks += 1
        if !condition {
            failures += 1
            print("FAIL line \(line): \(message)")
        }
    }

    static func throwsError(_ body: () throws -> Void) -> Bool {
        do {
            try body()
            return false
        } catch {
            return true
        }
    }

    static let uuid = "6EB8CC54-634C-4191-9A18-8287D20C55A1"
    static let otherUUID = "22E11AE9-A1A6-4533-8F4F-CBF82D1FF026"
    static let root = "/private/var/containers/Bundle/Application"

    static func main() {
        containerPaths()
        bundleIdentifiers()
        backupNames()
        backupSelection()
        manifests()
        unregistration()
        snapshotSelection()
        snapshotErrno()
        print("\(checks - failures)/\(checks) checks passed")
        exit(failures == 0 ? 0 : 1)
    }

    // MARK: - Container paths

    static func containerPaths() {
        let location = try? GuestSystemAppLocation(bundlePath: "\(root)/\(uuid)/News.app")
        check(location?.containerPath == "\(root)/\(uuid)", "container path")
        check(location?.appPath == "\(root)/\(uuid)/News.app", "app path")
        check(location?.containerUUID == uuid, "container UUID")
        check(location?.appDirectoryName == "News.app", "app directory name")

        let unprefixed = try? GuestSystemAppLocation(bundlePath: "/var/containers/Bundle/Application/\(uuid)/AppStore.app/")
        check(unprefixed?.containerPath == "\(root)/\(uuid)", "/var path and trailing slash normalized")

        let lowercase = try? GuestSystemAppLocation(bundlePath: "\(root)/\(uuid.lowercased())/Home.app")
        check(lowercase?.containerUUID == uuid.lowercased(), "lowercase UUID kept as written")

        let refused = [
            "/Applications/MobilePhone.app",
            "/Applications/Preferences.app",
            "/System/Library/AppPlaceholders/News.app",
            "/private/var/staged_system_apps/News.app",
            "\(root)/\(uuid)/../\(otherUUID)/News.app",
            "\(root)/../../../../System/Library/CoreServices/SpringBoard.app",
            "\(root)/\(uuid)/./News.app",
            "\(root)/\(uuid)//News.app",
            "\(root)/.jbroot-000114514191980C/Applications/Irisin.app",
            "\(root)/\(uuid)/News.app/PlugIns/Widget.appex",
            "\(root)/\(uuid)/News.app/Extra.app",
            "\(root)/\(uuid)/.app",
            "\(root)/\(uuid)/.hidden.app",
            "\(root)/\(uuid)/News",
            "\(root)/\(uuid)",
            "\(root)/not-a-uuid/News.app",
            "\(root)/\(uuid)X/News.app",
            "/private/var/mobile/Containers/Data/Application/\(uuid)/News.app",
            "private/var/containers/Bundle/Application/\(uuid)/News.app",
            "",
            "/",
        ]
        for path in refused {
            check(throwsError { _ = try GuestSystemAppLocation(bundlePath: path) }, "refuses \(path)")
        }
        do {
            _ = try GuestSystemAppLocation(bundlePath: "/Applications/MobilePhone.app")
        } catch {
            check(error == .notInBundleContainer("/Applications/MobilePhone.app"), "Phone refused as not in a container")
        }
        check(throwsError { _ = try GuestSystemAppLocation(containerUUID: "../../System", appDirectoryName: "X.app") },
              "manifest UUID traversal refused")
        check(throwsError { _ = try GuestSystemAppLocation(containerUUID: uuid, appDirectoryName: "../X.app") },
              "manifest app traversal refused")
    }

    // MARK: - Bundle identifiers

    static func bundleIdentifiers() {
        for id in ["com.apple.news", "com.apple.MobileSMS", "com.apple.AppStore", "com.apple.Passbook", "com.apple.tv"] {
            check(!throwsError { try GuestSystemAppPolicy.validateBundleID(id) }, "accepts \(id)")
        }
        for id in ["", "com.apple.", "com.apple..news", "com.apple.news/../x", "com.apple.news x", "com.apple.news\n",
                   "../com.apple.news", "com.apple.nëws"]
        {
            check(throwsError { try GuestSystemAppPolicy.validateBundleID(id) }, "refuses \(id.debugDescription)")
        }
        do {
            try GuestSystemAppPolicy.validateBundleID("com.example.app")
            check(false, "third-party app refused")
        } catch {
            check(error == .notSystemApp("com.example.app"), "third-party app is not a system app")
        }
    }

    // MARK: - Unregistration

    /// A record LaunchServices still lists right after unregistration is
    /// looked at again for 2.5 s, unregistered once more, looked at for
    /// another 2.5 s, and only then failed.
    static func unregistration() {
        typealias U = GuestAppUnregistration
        check(U.settleTimeout >= 2 && U.settleTimeout <= 3, "waits 2 to 3 s for the record to go")
        check(U.pollInterval > 0 && U.pollInterval <= 0.25, "looks again at a short interval")
        check(U.attempts == 2, "one retry")
        check(U.next(registered: false, attempt: 1, waited: 0) == .done, "gone at once")
        check(U.next(registered: false, attempt: 1, waited: 1.2) == .done, "gone while waiting")
        check(U.next(registered: false, attempt: 2, waited: 9) == .done, "gone after the retry, however late it is seen")
        check(U.next(registered: true, attempt: 1, waited: 0) == .wait, "still listed right after: wait")
        check(U.next(registered: true, attempt: 1, waited: U.settleTimeout - 0.1) == .wait, "still listed before the timeout: wait")
        check(U.next(registered: true, attempt: 1, waited: U.settleTimeout) == .retry, "still listed at the timeout: unregister again")
        check(U.next(registered: true, attempt: 2, waited: 0.5) == .wait, "the retry waits as well")
        check(U.next(registered: true, attempt: 2, waited: U.settleTimeout) == .fail, "still listed after the retry: fail")
        check(U.next(registered: true, attempt: 3, waited: U.settleTimeout) == .fail, "never more than the attempts")

        // The decision loop the daemon runs, against a record that goes on
        // the given look (counting every look across attempts).
        func simulate(goneOnLook gone: Int?) -> (outcome: U.Next, attempts: Int, looks: Int) {
            var attempt = 1
            var looks = 0
            var waited: TimeInterval = 0
            while true {
                looks += 1
                let registered = gone.map { looks < $0 } ?? true
                let next = U.next(registered: registered, attempt: attempt, waited: waited)
                switch next {
                case .done, .fail: return (next, attempt, looks)
                case .wait: waited += U.pollInterval
                case .retry:
                    attempt += 1
                    waited = 0
                }
            }
        }
        let immediate = simulate(goneOnLook: 1)
        check(immediate.outcome == .done && immediate.attempts == 1 && immediate.looks == 1, "a clean unregistration looks once")
        let late = simulate(goneOnLook: 5)
        check(late.outcome == .done && late.attempts == 1, "a record that goes within the wait needs no retry")
        let perLook = Int((U.settleTimeout / U.pollInterval).rounded(.up)) + 1
        let retried = simulate(goneOnLook: perLook + 3)
        check(retried.outcome == .done && retried.attempts == 2, "a record that outlasts the wait is unregistered again")
        let stuck = simulate(goneOnLook: nil)
        check(stuck.outcome == .fail && stuck.attempts == 2, "a record that never goes fails after the retry")
        check(stuck.looks <= 2 * (perLook + 1), "and the looks are bounded")
    }

    // MARK: - Backup names

    static func backupNames() {
        let directory = "/private/var/db/vphoned/removed-system-apps"
        let legacy = "/private/var/mobile/Library/removed-system-apps"
        check(GuestSystemAppPolicy.backupDirectory == directory, "backup directory is on the data volume")
        check(GuestSystemAppPolicy.legacyBackupDirectory == legacy, "legacy backup directory")
        check(GuestSystemAppPolicy.backupDirectories == [directory, legacy], "search order: new, then legacy")
        check(GuestSystemAppPolicy.isLegacy(legacy) && !GuestSystemAppPolicy.isLegacy(directory), "legacy detection")
        check(!GuestSystemAppPolicy.isLegacy(legacy + "/"), "legacy detection is exact")
        check(GuestSystemAppPolicy.backupContainerPath("com.apple.news", in: legacy) == "\(legacy)/com.apple.news.container",
              "legacy backup container path")
        check(GuestSystemAppPolicy.manifestPath("com.apple.news", in: legacy) == "\(legacy)/com.apple.news.manifest.json",
              "legacy manifest path")
        check(GuestSystemAppPolicy.backupContainerPath("com.apple.news") == "\(directory)/com.apple.news.container",
              "backup container path")
        check(GuestSystemAppPolicy.manifestPath("com.apple.news") == "\(directory)/com.apple.news.manifest.json",
              "manifest path")
        check(GuestSystemAppPolicy.bundleID(forBackupEntry: "com.apple.news.container") == "com.apple.news",
              "id from container entry")
        check(GuestSystemAppPolicy.bundleID(forBackupEntry: "com.apple.news.manifest.json") == "com.apple.news",
              "id from manifest entry")
        for name in ["News.container", "com.apple.news.container.partial", ".DS_Store", "com.apple.news", ".container"] {
            check(GuestSystemAppPolicy.bundleID(forBackupEntry: name) == nil, "ignores entry \(name)")
        }
    }

    // MARK: - Backup selection

    static func backupSelection() {
        let current = GuestSystemAppPolicy.backupDirectory
        let legacy = GuestSystemAppPolicy.legacyBackupDirectory
        let id = "com.apple.news"
        func holding(_ present: Set<String>) -> String? {
            GuestSystemAppPolicy.backupDirectory(holding: id) { present.contains($0) }
        }
        let currentManifest = "\(current)/\(id).manifest.json"
        let currentContainer = "\(current)/\(id).container"
        let legacyManifest = "\(legacy)/\(id).manifest.json"
        let legacyContainer = "\(legacy)/\(id).container"

        check(holding([]) == nil, "no backup anywhere")
        check(holding([currentManifest, currentContainer]) == current, "new backup")
        check(holding([legacyManifest, legacyContainer]) == legacy, "legacy backup only")
        check(holding([currentManifest, currentContainer, legacyManifest, legacyContainer]) == current,
              "new backup wins over a legacy one")
        check(holding([legacyManifest, legacyContainer, currentContainer]) == legacy,
              "a manifest wins over a stray container")
        check(holding([currentManifest]) == current, "manifest alone (container already moved back)")
        check(holding([legacyContainer]) == legacy, "container without a manifest is still found")
        check(holding(["\(legacy)/News.container"]) == nil, "a hand-made backup names no app")
        check(holding(["\(current)/com.apple.tv.manifest.json"]) == nil, "another app's backup")

        check(GuestSystemAppPolicy.restoreCopiesAcrossVolumes(renameErrno: EXDEV), "EXDEV copies across volumes")
        for code in [EPERM, EACCES, ENOENT, EEXIST, ENOTEMPTY, EBUSY, EIO] {
            check(!GuestSystemAppPolicy.restoreCopiesAcrossVolumes(renameErrno: code), "errno \(code) does not copy")
        }
    }

    // MARK: - Manifests

    static func manifests() {
        guard let location = try? GuestSystemAppLocation(bundlePath: "\(root)/\(uuid)/FindMy.app") else {
            check(false, "location for manifest")
            return
        }
        let date = Date(timeIntervalSince1970: 1_791_414_420)
        let manifest = GuestSystemAppManifest(bundleID: "com.apple.findmy", location: location, removedAt: date)
        guard let data = try? manifest.encoded() else {
            check(false, "manifest encodes")
            return
        }
        let decoded = try? GuestSystemAppManifest.decode(data, expectedBundleID: "com.apple.findmy")
        check(decoded == manifest, "manifest round trip")
        check((try? decoded?.location()) == location, "manifest location round trip")

        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        check(Set(object.keys) == ["version", "bundle_id", "container_uuid", "app", "container_path", "removed_at"],
              "manifest keys")
        check(object["container_path"] as? String == "\(root)/\(uuid)", "manifest container path")
        check(object["removed_at"] as? String == "2026-10-07T23:07:00Z", "manifest date is ISO 8601")

        check(throwsError { _ = try GuestSystemAppManifest.decode(data, expectedBundleID: "com.apple.news") },
              "manifest for another app refused")
        check(throwsError { _ = try GuestSystemAppManifest.decode(Data("not json".utf8), expectedBundleID: "com.apple.findmy") },
              "garbage refused")

        func tampered(_ key: String, _ value: Any) -> Data {
            var copy = object
            copy[key] = value
            return (try? JSONSerialization.data(withJSONObject: copy)) ?? Data()
        }
        check(throwsError { _ = try GuestSystemAppManifest.decode(tampered("container_uuid", "../../../System"),
                                                                  expectedBundleID: "com.apple.findmy") },
              "tampered UUID refused")
        check(throwsError { _ = try GuestSystemAppManifest.decode(tampered("app", "../../Applications/X.app"),
                                                                  expectedBundleID: "com.apple.findmy") },
              "tampered app refused")
        check(throwsError { _ = try GuestSystemAppManifest.decode(tampered("version", 2),
                                                                  expectedBundleID: "com.apple.findmy") },
              "unknown version refused")
        check(throwsError {
            _ = try GuestSystemAppManifest.decode(tampered("bundle_id", "com.example.app"), expectedBundleID: "com.example.app")
        }, "third-party manifest refused")
    }

    // MARK: - Snapshot names

    static func snapshotSelection() {
        typealias Selection = GuestSnapshotPolicy.Selection
        let prefix = "orig-fs.disabled.rn-"
        let snapshots = [
            "com.apple.os.update-4EC2ECB9",
            "\(prefix)4EC2ECB9",
            "\(prefix)7A11",
            "com.apple.TimeMachine.2026-10-07-230000.local",
        ]

        check((try? Selection.make(name: nil, prefix: nil)) == .prefix(prefix), "default selects the CFW prefix")
        check((try? Selection.make(name: nil, prefix: nil))?.targets(in: snapshots) == ["\(prefix)4EC2ECB9", "\(prefix)7A11"],
              "default deletes only orig-fs snapshots")
        check((try? Selection.make(name: nil, prefix: "\(prefix)4E"))?.targets(in: snapshots) == ["\(prefix)4EC2ECB9"],
              "narrower prefix")
        check((try? Selection.make(name: "\(prefix)4EC2ECB9", prefix: nil))?.targets(in: snapshots) == ["\(prefix)4EC2ECB9"],
              "exact name")
        check((try? Selection.make(name: "\(prefix)GONE", prefix: nil))?.targets(in: snapshots) == ["\(prefix)GONE"],
              "an unlisted name is still tried")
        check((try? Selection.make(name: nil, prefix: nil))?.targets(in: ["com.apple.os.update-4EC2ECB9"]) == [],
              "nothing matched selects nothing")
        check((try? Selection.make(name: nil, prefix: nil))?.targets(in: []) == [], "empty volume selects nothing")

        for name in ["com.apple.os.update-4EC2ECB9", prefix, "orig-fs", "x\(prefix)A", "ORIG-FS.DISABLED.RN-A"] {
            check(throwsError { _ = try Selection.make(name: name, prefix: nil) }, "refuses name \(name)")
        }
        for refusedPrefix in ["", "orig-fs", "com.apple.os.update-", "o"] {
            check(throwsError { _ = try Selection.make(name: nil, prefix: refusedPrefix) }, "refuses prefix \(refusedPrefix)")
        }
        check(throwsError { _ = try Selection.make(name: "\(prefix)A", prefix: prefix) }, "name and prefix together refused")
        check(throwsError { _ = try Selection.make(name: "\(prefix)A/B", prefix: nil) }, "slash in name refused")
        do {
            _ = try Selection.make(name: "com.apple.os.update-4EC2ECB9", prefix: nil)
        } catch {
            check(error == .refused("com.apple.os.update-4EC2ECB9"), "update snapshot refusal reason")
        }

        let selection = Selection.prefix(prefix)
        check(!selection.matches("com.apple.os.update-4EC2ECB9"), "update snapshot never matches")
        check(!Selection.name("com.apple.os.update-4EC2ECB9").matches("com.apple.os.update-4EC2ECB9"),
              "a hand-built selection still refuses the update snapshot")
        check(Selection.name("com.apple.os.update-4EC2ECB9").targets(in: snapshots) == [],
              "a hand-built selection never targets the update snapshot")

        check(!throwsError { try GuestSnapshotPolicy.validateMount("/") }, "root mount")
        check(!throwsError { try GuestSnapshotPolicy.validateMount("/private/var") }, "data mount")
        for mount in ["", "private/var", "/private/../System", "/./"] {
            check(throwsError { try GuestSnapshotPolicy.validateMount(mount) }, "refuses mount \(mount)")
        }
    }

    // MARK: - errno

    static func snapshotErrno() {
        typealias Failure = GuestSnapshotPolicy.Failure
        check(Failure(errno: ENOENT) == .alreadyDeleted, "ENOENT is already deleted")
        check(Failure(errno: EPERM) == .notPermitted, "EPERM is not permitted")
        check(Failure(errno: EACCES) == .notPermitted, "EACCES is not permitted")
        check(Failure(errno: EBUSY) == .busy, "EBUSY is busy")
        check(Failure(errno: EINVAL) == .invalidRequest, "EINVAL is an invalid request")
        check(Failure(errno: ENOTSUP) == .invalidRequest, "ENOTSUP is an invalid request")
        check(Failure(errno: EIO) == .failed, "EIO fails")
        check(Failure(errno: EBUSY).retryable, "busy is retryable")
        for failure in [Failure.alreadyDeleted, .notPermitted, .invalidRequest, .failed] {
            check(!failure.retryable, "\(failure.rawValue) is not retryable")
        }
        check(Failure.notPermitted.rawValue == "not_permitted" && Failure.alreadyDeleted.rawValue == "already_deleted"
            && Failure.invalidRequest.rawValue == "invalid_request", "wire reasons")
        let message = GuestSnapshotPolicy.message(.notPermitted, errno: EPERM, operation: "fs_snapshot_delete(x)")
        check(message.contains("carry com.apple.private.vfs.snapshot") && message.contains("root"),
              "permission message names the entitlement")
        check(GuestSnapshotPolicy.message(.busy, errno: EBUSY, operation: "x").contains("retry"), "busy message says retry")
    }
}
