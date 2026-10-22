import Darwin
import Foundation

// MARK: - APFS Snapshot Deletion Policy

/// Which APFS snapshots `apfs.snapshot.delete` may remove and how it reads
/// the kernel's answer, kept free of IcliKit and UIKit so
/// `VPhoneDaemon/Tests/run-system-maintenance-tests.sh` checks it on the Mac.
///
/// CFW install renames the system volume's sealed update snapshot
/// (`com.apple.os.update-<hash>`) to `orig-fs.disabled.rn-<hash>` and the
/// patched kernel boots the live file system instead. The renamed snapshot is
/// then an ordinary dangling snapshot that pins every block a later file trim
/// frees. Only that prefix is ever deleted: another snapshot may be the
/// volume's root or revert target, and deleting it can leave the guest unable
/// to boot. `Research/Guest/template_snapshot_deletion.md` has the evidence.
enum GuestSnapshotPolicy {
    static let deletablePrefix = "orig-fs.disabled.rn-"
    static let defaultMount = "/"

    /// The snapshots a request selects: `name` alone, every snapshot starting
    /// with `prefix`, or with neither every deletable one.
    enum Selection: Equatable {
        case name(String)
        case prefix(String)

        static func make(name: String?, prefix: String?) throws(GuestSnapshotPolicyError) -> Selection {
            switch (name, prefix) {
            case (.some, .some):
                throw .invalidRequest("Pass name or prefix, not both")
            case let (.some(name), nil):
                guard name.hasPrefix(deletablePrefix), name.count > deletablePrefix.count else {
                    throw .refused(name)
                }
                guard !name.contains("/") else { throw .invalidRequest("\(name) is not a snapshot name") }
                return .name(name)
            case let (nil, .some(prefix)):
                guard prefix.hasPrefix(deletablePrefix) else { throw .refused(prefix + "*") }
                return .prefix(prefix)
            case (nil, nil):
                return .prefix(deletablePrefix)
            }
        }

        func matches(_ snapshot: String) -> Bool {
            guard snapshot.hasPrefix(GuestSnapshotPolicy.deletablePrefix) else { return false }
            switch self {
            case let .name(name): return snapshot == name
            case let .prefix(prefix): return snapshot.hasPrefix(prefix)
            }
        }

        /// The listed snapshots this selection deletes. A name that is not
        /// listed is still tried, so a stale listing cannot hide it; ENOENT
        /// then counts as already deleted.
        func targets(in snapshots: [String]) -> [String] {
            switch self {
            case let .name(name): matches(name) ? [name] : []
            case .prefix: snapshots.filter(matches)
            }
        }
    }

    /// A mount point is an absolute path without `.` or `..` components.
    static func validateMount(_ mount: String) throws(GuestSnapshotPolicyError) {
        guard mount.hasPrefix("/"),
              !mount.split(separator: "/").contains(where: { $0 == "." || $0 == ".." })
        else {
            throw .invalidRequest("mount must be an absolute path: \(mount)")
        }
    }

    // MARK: - errno

    enum Failure: String, Equatable {
        /// The snapshot is not there: a delete counts it as done.
        case alreadyDeleted = "already_deleted"
        /// vphoned lacks `com.apple.private.vfs.snapshot` or is not root.
        case notPermitted = "not_permitted"
        /// Mounted, or APFS is still merging an earlier deletion. Retry later.
        case busy
        /// Not APFS, or a snapshot the kernel will not delete (root or revert target).
        case invalidRequest = "invalid_request"
        case failed

        init(errno code: Int32) {
            switch code {
            case ENOENT: self = .alreadyDeleted
            case EPERM, EACCES: self = .notPermitted
            case EBUSY: self = .busy
            case EINVAL, ENOTSUP: self = .invalidRequest
            default: self = .failed
            }
        }

        var retryable: Bool {
            self == .busy
        }
    }

    static func message(_ failure: Failure, errno code: Int32, operation: String) -> String {
        let reason = String(cString: strerror(code))
        return switch failure {
        case .alreadyDeleted:
            "\(operation): the snapshot no longer exists (\(reason))"
        case .notPermitted:
            "\(operation): \(reason). vphoned must run as root and carry com.apple.private.vfs.snapshot (com.apple.developer.vfs.snapshot alone is refused)"
        case .busy:
            "\(operation): \(reason). The snapshot is mounted or APFS is still merging an earlier deletion; retry later"
        case .invalidRequest:
            "\(operation): \(reason). The volume is not APFS, or the kernel will not delete this snapshot"
        case .failed:
            "\(operation): \(reason) (errno \(code))"
        }
    }
}

enum GuestSnapshotPolicyError: Error, Equatable, CustomStringConvertible {
    case invalidRequest(String)
    case refused(String)

    var description: String {
        switch self {
        case let .invalidRequest(message):
            message
        case let .refused(name):
            "Refusing to delete \(name): only \(GuestSnapshotPolicy.deletablePrefix)* snapshots, "
                + "which CFW install leaves behind, may be deleted"
        }
    }
}
