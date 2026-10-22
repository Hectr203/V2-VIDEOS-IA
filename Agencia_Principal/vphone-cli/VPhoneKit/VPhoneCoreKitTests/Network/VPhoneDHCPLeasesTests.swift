import Foundation
import Testing
@testable import VPhoneCoreKit

/// bootpd's lease list: reading it as bootpd writes it, deciding which
/// entries no machine owns, and rewriting it without them.
struct VPhoneDHCPLeasesTests {
    typealias Lease = VPhoneDHCPLeaseList.Lease

    /// Seconds since 1970 that every expiry below is measured against.
    static let now = Date(timeIntervalSince1970: 0x6AC1_0000)
    static let shared = VPhoneIPv4Subnet(containing: VPhoneIPv4Address(192, 168, 64, 1), prefixLength: 24)!

    static func block(name: String, ip: String, mac: String, lease: Int) -> String {
        """
        {
        \tname=\(name)
        \tip_address=\(ip)
        \thw_address=1,\(mac)
        \tidentifier=1,\(mac)
        \tlease=0x\(String(lease, radix: 16))
        }

        """
    }

    static let sample = [
        // A machine's own lease, expired while it is stopped.
        block(name: "iPad", ip: "192.168.64.22", mac: "2:8b:e3:17:a4:a0", lease: 0x6AC0_0000),
        // An iOS guest no machine claims, long expired.
        block(name: "iPhone", ip: "192.168.64.125", mac: "3e:4d:1e:9c:61:85", lease: 0x6AC0_0000),
        // One no machine claims, still inside its lease.
        block(name: "iPhone", ip: "192.168.64.126", mac: "e:2f:62:cd:88:2f", lease: 0x6AC2_0000),
        // Another app's VM.
        block(name: "ManagedlMachine", ip: "192.168.64.2", mac: "86:44:f:12:49:26", lease: 0x6AB0_0000),
        // An iPhone on Internet Sharing, not on vmnet's network.
        block(name: "iPhone", ip: "192.168.2.5", mac: "aa:bb:cc:dd:ee:1", lease: 0x6AB0_0000),
    ].joined()

    static let machines: [VPhoneMACAddress: String] = [
        VPhoneMACAddress(string: "02:8b:e3:17:a4:a0")!: "ipad-pro-13",
    ]

    // MARK: - Parsing

    @Test func `reads each entry and writes the file back unchanged`() throws {
        let list = try VPhoneDHCPLeaseList(text: Self.sample)
        #expect(list.leases.count == 5)
        #expect(list.text == Self.sample)

        let first = list.leases[0]
        #expect(first.name == "iPad")
        #expect(first.address == VPhoneIPv4Address(192, 168, 64, 22))
        #expect(first.expiry == Date(timeIntervalSince1970: 0x6AC0_0000))
    }

    /// bootpd drops the leading zero of each byte.
    @Test func `hardware addresses without leading zeros`() {
        #expect(Lease.hardwareAddress("1,e:2f:62:cd:88:2f") == VPhoneMACAddress(string: "0e:2f:62:cd:88:2f"))
        #expect(Lease.hardwareAddress("1,86:44:f:12:49:26") == VPhoneMACAddress(string: "86:44:0f:12:49:26"))
        #expect(Lease.hardwareAddress("6,e:2f:62:cd:88:2f") == nil)
        #expect(Lease.hardwareAddress("1,e:2f:62:cd:88") == nil)
        #expect(Lease.hardwareAddress("1,e:2f:62:cd:88:2ff") == nil)
    }

    @Test func `an entry without a lease never expires`() throws {
        let list = try VPhoneDHCPLeaseList(text: "{\n\tname=iPhone\n\tip_address=192.168.64.9\n}\n")
        #expect(list.leases[0].expiry == nil)
        #expect(!list.leases[0].isExpired(at: .distantFuture))
    }

    /// Lines bootpd would merely skip are refused, so a file in a shape this
    /// reader does not expect is never rewritten.
    @Test func `refuses a file bootpd did not write`() {
        #expect(throws: VPhoneDHCPLeaseError.malformed(line: 2)) {
            try VPhoneDHCPLeaseList(text: "{\n{\n}\n")
        }
        #expect(throws: VPhoneDHCPLeaseError.malformed(line: 1)) {
            try VPhoneDHCPLeaseList(text: "}\n")
        }
        #expect(throws: VPhoneDHCPLeaseError.malformed(line: 1)) {
            try VPhoneDHCPLeaseList(text: "name=iPhone\n")
        }
        #expect(throws: VPhoneDHCPLeaseError.self) {
            try VPhoneDHCPLeaseList(text: "{\n\tname=iPhone\n")
        }
    }

    @Test func `an empty file has no entries`() throws {
        #expect(try VPhoneDHCPLeaseList(text: "").leases.isEmpty)
    }

    // MARK: - Audit

    @Test func `only an expired guest no machine claims is an orphan`() throws {
        let audit = try VPhoneDHCPLeaseAudit(
            VPhoneDHCPLeaseList(text: Self.sample),
            machines: Self.machines,
            sharedSubnet: Self.shared,
            now: Self.now,
        )
        #expect(audit.entries.map(\.owner) == [.machine("ipad-pro-13"), .orphan, .active, .foreign, .foreign])
        #expect(audit.orphans.map(\.address) == [VPhoneIPv4Address(192, 168, 64, 125)])
    }

    /// A stopped machine's lease runs out like any other; it must still be
    /// kept, or the machine comes back on another address.
    @Test func `a machine's expired lease is kept`() throws {
        let audit = try VPhoneDHCPLeaseAudit(
            VPhoneDHCPLeaseList(text: Self.sample),
            machines: Self.machines,
            sharedSubnet: Self.shared,
            now: .distantFuture,
        )
        #expect(audit.entries[0].owner == .machine("ipad-pro-13"))
        #expect(audit.orphans.count == 2)
    }

    // MARK: - Release

    @Test func `release rewrites the file without the selected entries`() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("vphone-leases-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("dhcpd_leases").path
        try Self.sample.write(toFile: path, atomically: false, encoding: .utf8)
        chmod(path, 0o644)

        let released = try VPhoneDHCPLeaseRelease.release(at: path, notifyServer: false) { list in
            VPhoneDHCPLeaseAudit(list, machines: Self.machines, sharedSubnet: Self.shared, now: Self.now).orphans
        }
        #expect(released.map(\.address) == [VPhoneIPv4Address(192, 168, 64, 125)])

        let rewritten = try VPhoneDHCPLeaseList(text: String(contentsOfFile: path, encoding: .utf8))
        #expect(rewritten.leases.count == 4)
        #expect(!rewritten.leases.contains { $0.address == VPhoneIPv4Address(192, 168, 64, 125) })
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        #expect((attributes[.posixPermissions] as? Int) == 0o644)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["dhcpd_leases"])

        // Nothing left to release: the file is not touched again.
        let before = try FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date
        let again = try VPhoneDHCPLeaseRelease.release(at: path, notifyServer: false) { list in
            VPhoneDHCPLeaseAudit(list, machines: Self.machines, sharedSubnet: Self.shared, now: Self.now).orphans
        }
        #expect(again.isEmpty)
        #expect(try FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date == before)
    }

    @Test func `release leaves a malformed file alone`() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("vphone-leases-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("dhcpd_leases").path
        let text = Self.sample + "{\n"
        try text.write(toFile: path, atomically: false, encoding: .utf8)

        #expect(throws: VPhoneDHCPLeaseError.self) {
            try VPhoneDHCPLeaseRelease.release(at: path, notifyServer: false) { $0.leases }
        }
        #expect(try String(contentsOfFile: path, encoding: .utf8) == text)
    }
}
