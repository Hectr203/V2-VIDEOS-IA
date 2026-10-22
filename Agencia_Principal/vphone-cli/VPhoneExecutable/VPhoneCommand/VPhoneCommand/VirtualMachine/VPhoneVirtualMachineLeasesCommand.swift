import ArgumentParser
import Darwin
import Foundation
import VPhoneCoreKit

// MARK: - leases

/// The Mac's DHCP leases on vmnet's shared network, and who owns each. bootpd
/// keeps an address bound to a MAC after the lease runs out, so a guest that
/// left with its MAC still holds one; `--release-orphans` frees those.
struct VPhoneVirtualMachineLeasesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "leases",
        abstract: "Show the nat network's DHCP leases, or release the ones no machine owns",
        discussion: """
        The Mac's DHCP server keeps each address bound to the guest MAC it was given to, \
        even after the lease runs out. A deleted machine, a replaced MAC, or a launch from \
        before MACs were saved leaves its address held by a MAC no machine uses any more, so \
        new guests take ever higher addresses, towards the fixed ones picked high in the range.

        An orphan is an iOS or iPadOS guest's lease on the shared network whose MAC belongs to \
        no machine in the library and whose lease has run out. Leases of other VM apps, of \
        devices on Internet Sharing, and of anything still inside its lease are never released.

        --release-orphans removes the orphans from /var/db/dhcpd_leases and has the DHCP \
        server read it again. It needs root. A machine kept in another library is only known \
        if that library is named too: repeat --library-root for each.
        """,
    )

    @Option(
        name: [.customShort("l"), .long],
        help: "VM library root, repeatable (default: ~/.vphone/machines or $VPHONE_LIBRARY_ROOT)",
    )
    var libraryRoot: [String] = []
    @Flag(name: .long, help: "Remove the orphaned leases (needs sudo)")
    var releaseOrphans = false
    @Flag(name: .shortAndLong, help: "Emit JSON") var json = false

    func run() throws {
        if releaseOrphans, geteuid() != 0 {
            throw ValidationError("Releasing leases changes \(VPhoneDHCPLeaseList.path), which needs root. Run this command with sudo.")
        }
        let machines = try machineMACs()
        let subnet = VPhoneNetworkHost.current.sharedNATSubnet
        let audit = { (list: VPhoneDHCPLeaseList) in
            VPhoneDHCPLeaseAudit(list, machines: machines, sharedSubnet: subnet)
        }

        if releaseOrphans {
            let released = try VPhoneDHCPLeaseRelease.release { audit($0).orphans }
            if json {
                try printJSON(["released": released.map(Self.report)])
                return
            }
            for lease in released {
                print("released \(Self.address(lease))  \(Self.mac(lease))")
            }
            print(released.isEmpty ? "No orphaned leases." : "Released \(released.count) orphaned lease\(released.count == 1 ? "" : "s").")
            return
        }

        let entries = try audit(readList()).entries.filter { $0.owner != .foreign }
        if json {
            try printJSON(entries.map { entry in
                var report = Self.report(entry.lease)
                switch entry.owner {
                case let .machine(name):
                    report["owner"] = "machine"
                    report["machine"] = name
                case .foreign: report["owner"] = "foreign"
                case .active: report["owner"] = "active"
                case .orphan: report["owner"] = "orphan"
                }
                return report
            })
            return
        }
        guard !entries.isEmpty else {
            print("No guest leases on \(subnet).")
            return
        }
        let now = Date()
        for entry in entries.sorted(by: { ($0.lease.address?.raw ?? 0) < ($1.lease.address?.raw ?? 0) }) {
            let owner = switch entry.owner {
            case let .machine(name): name
            case .foreign: "foreign"
            case .active: "unowned, in use"
            case .orphan: "orphan"
            }
            let address = Self.address(entry.lease).padding(toLength: 16, withPad: " ", startingAt: 0)
            let mac = Self.mac(entry.lease).padding(toLength: 18, withPad: " ", startingAt: 0)
            let name = (entry.lease.name ?? "").padding(toLength: 7, withPad: " ", startingAt: 0)
            print("\(address) \(mac) \(name) \(owner)  \(Self.expiry(entry.lease, now: now))")
        }
        let orphans = entries.count { $0.owner == .orphan }
        if orphans > 0 {
            print("\n\(orphans) orphaned lease\(orphans == 1 ? "" : "s"). Release with: sudo vphone-cli vm leases --release-orphans")
        }
    }

    // MARK: - Machines

    /// The MACs every machine in the named libraries claims. A library that
    /// could not be read in full refuses a release: a machine skipped here
    /// would have its lease taken for an orphan.
    private func machineMACs() throws -> [VPhoneMACAddress: String] {
        let roots = libraryRoot.isEmpty
            ? [VPhoneLibrary.defaultRoot()]
            : libraryRoot.map { URL(fileURLWithPath: $0, isDirectory: true) }
        var bundles: [VPhoneBundle] = []
        for root in roots {
            let scan = try VPhoneLibrary(root: root).scan()
            for skip in scan.skipped {
                FileHandle.standardError.write(Data("warning: skipping \(skip.name): \(skip.reason)\n".utf8))
            }
            if releaseOrphans {
                if let skip = scan.skipped.first {
                    throw ValidationError("Unable to read \(skip.name) in \(root.path), so its lease cannot be told from an orphan. Nothing was released.")
                }
                if scan.bundles.isEmpty {
                    throw ValidationError("No machines in \(root.path). Name the library with --library-root, or every machine's lease there would be released.")
                }
            }
            bundles += scan.bundles
        }
        return VPhoneDHCPLeaseAudit.machineMACs(bundles)
    }

    private func readList() throws -> VPhoneDHCPLeaseList {
        guard let data = FileManager.default.contents(atPath: VPhoneDHCPLeaseList.path) else {
            // bootpd creates it at its first lease.
            return VPhoneDHCPLeaseList(leases: [])
        }
        return try VPhoneDHCPLeaseList(text: String(decoding: data, as: UTF8.self))
    }

    // MARK: - Output

    private static func address(_ lease: VPhoneDHCPLeaseList.Lease) -> String {
        lease.address?.description ?? "?"
    }

    private static func mac(_ lease: VPhoneDHCPLeaseList.Lease) -> String {
        lease.hardwareAddress?.description ?? "?"
    }

    private static func expiry(_ lease: VPhoneDHCPLeaseList.Lease, now: Date) -> String {
        guard let expiry = lease.expiry else { return "permanent" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let relative = formatter.localizedString(for: expiry, relativeTo: now)
        return expiry <= now ? "expired \(relative)" : "expires \(relative)"
    }

    private static func report(_ lease: VPhoneDHCPLeaseList.Lease) -> [String: Any] {
        var report: [String: Any] = [:]
        report["address"] = lease.address?.description
        report["mac"] = lease.hardwareAddress?.description
        report["name"] = lease.name
        report["expires"] = lease.expiry.map { Int($0.timeIntervalSince1970) }
        return report
    }

    private func printJSON(_ object: Any) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    }
}
