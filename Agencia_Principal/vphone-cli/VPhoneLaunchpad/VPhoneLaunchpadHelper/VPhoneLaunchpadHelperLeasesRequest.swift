import Darwin
import Foundation

/// A validated `vphone-cli vm leases --release-orphans` invocation. Built only
/// from a store bundle whose cdhash still matches its receipt, and only for
/// library folders the calling user owns.
///
/// The command rewrites `/var/db/dhcpd_leases` without the entries of iOS
/// guests whose MAC no machine in these libraries has, and only once their
/// lease has run out. The libraries are what it compares against, so a
/// library left out makes its machines' expired leases look orphaned; the
/// command refuses one with no machines or an unreadable machine itself.
struct VPhoneLaunchpadHelperLeasesRequest {
    /// More libraries than anyone keeps; a longer list is not a real request.
    static let maximumLibraries = 32

    let executable: URL
    let arguments: [String]
    let environment: [String: String]

    init(bundleVersion: String, libraryRoots: [String], callerUID: uid_t, callerGID: gid_t) throws {
        guard VPhoneLaunchpadNames.isCompatibleBundleVersion(bundleVersion) else {
            throw VPhoneLaunchpadHelperError("VPhone.bundle \(bundleVersion) is not supported. Use \(VPhoneLaunchpadNames.minimumBundleVersion) or newer.")
        }
        guard let receipt = VPhoneLaunchpadBundleReceipt.load(version: bundleVersion) else {
            throw VPhoneLaunchpadHelperError("VPhone.bundle \(bundleVersion) is not installed. Install it in Core Bundle, then try again.")
        }
        let executable = VPhoneLaunchpadBundleStore.executable(version: bundleVersion, named: "vphone-cli")
        try VPhoneLaunchpadHelperCodeCheck.requireCDHash(executable, receipt.cdhashes["vphone-cli"])

        var roots: [String] = []
        for root in libraryRoots where !roots.contains(root) {
            roots.append(root)
        }
        guard !roots.isEmpty else {
            throw VPhoneLaunchpadHelperError("Name at least one machine library.")
        }
        guard roots.count <= Self.maximumLibraries else {
            throw VPhoneLaunchpadHelperError("Too many machine libraries.")
        }
        // Checked as for a CFW install: walked from "/" without following a
        // link, and owned by the caller.
        for root in roots {
            let descriptor = try VPhoneLaunchpadHelperLibraryPath.openDirectory(root)
            defer { close(descriptor) }
            try VPhoneLaunchpadHelperLibraryPath.requireOwner(descriptor, root, callerUID)
        }

        self.executable = executable
        arguments = ["vm", "leases", "--release-orphans", "--json"] + roots.flatMap { ["--library-root", $0] }
        environment = try VPhoneLaunchpadHelperLibraryPath.environment(callerUID: callerUID, callerGID: callerGID)
    }
}
