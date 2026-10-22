import Darwin
import Foundation

// MARK: - Rootless root

extension GuestIrisinInstaller {
    static let rootlessRoot = "/var/jb"

    /// `/var/jb` is normally a link into `/private/preboot`. Only a standard
    /// path strictly below `/private/preboot` is accepted as its target, so
    /// removal never follows the link anywhere else.
    static func rootlessLinkTarget(_ root: String) throws -> String {
        var target = [CChar](repeating: 0, count: Int(PATH_MAX))
        let count = readlink(root, &target, target.count - 1)
        guard count > 0 else { throw GuestAPIError.operationFailed("Could not read bootstrap link: \(root)") }
        guard let physicalPath = String(
            bytes: target.prefix(count).map { UInt8(bitPattern: $0) }, encoding: .utf8,
        ) else { throw GuestAPIError.operationFailed("Bootstrap link has an invalid path: \(root)") }
        guard physicalPath.hasPrefix("/private/preboot/"),
              physicalPath != "/private/preboot/",
              physicalPath == (physicalPath as NSString).standardizingPath
        else {
            throw GuestAPIError.operationFailed("Rootless bootstrap link has an unexpected target: \(physicalPath)")
        }
        return physicalPath
    }
}
