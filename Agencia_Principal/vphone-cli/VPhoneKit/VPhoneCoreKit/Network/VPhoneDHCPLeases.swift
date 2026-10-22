import Darwin
import Foundation

// MARK: - Lease list

/// bootpd's lease list, `/var/db/dhcpd_leases`, which vmnet's shared NAT
/// network hands out addresses from.
///
/// bootpd binds an address to a client's MAC for good. An expired lease still
/// holds its address for that MAC, and bootpd reclaims one only when every
/// other address in the pool is taken (`DHCPLeases_reclaim` in bootp's
/// `dhcpd.c`). A guest that left with its MAC (a deleted machine, a replaced
/// MAC, or any launch before MACs were saved) leaves its address bound to
/// nobody, so new guests climb through the pool towards the fixed addresses
/// users pick high in it, and once it is full bootpd reclaims the oldest
/// expired lease, which may be a stopped machine's.
public struct VPhoneDHCPLeaseList: Equatable, Sendable {
    public static let path = "/var/db/dhcpd_leases"

    public struct Lease: Equatable, Sendable {
        /// The host name the client sent. An iOS or iPadOS guest sends its
        /// device type, `iPhone` or `iPad`, whatever its own name.
        public var name: String?
        public var address: VPhoneIPv4Address?
        public var hardwareAddress: VPhoneMACAddress?
        /// When the lease runs out. Nil when the entry has no `lease`
        /// property, which bootpd treats as permanent.
        public var expiry: Date?
        /// The lines between `{` and `}`, written back as they were read so
        /// that nothing this type does not understand is lost.
        var lines: [String]

        init(lines: [String]) {
            self.lines = lines
            for line in lines {
                let trimmed = line.drop { $0 == " " || $0 == "\t" }
                guard let separator = trimmed.firstIndex(of: "=") else { continue }
                let value = String(trimmed[trimmed.index(after: separator)...])
                switch trimmed[..<separator] {
                case "name": name = value
                case "ip_address": address = VPhoneIPv4Address(dotted: value)
                case "hw_address": hardwareAddress = Self.hardwareAddress(value)
                case "lease": expiry = Self.expiry(value)
                default: break
                }
            }
        }

        /// bootpd writes `type,address` with each byte in hex and no leading
        /// zero (`1,a:8c:c9:1e:fc:45`). Type 1 is Ethernet.
        static func hardwareAddress(_ value: String) -> VPhoneMACAddress? {
            let parts = value.split(separator: ",", maxSplits: 1)
            guard parts.count == 2, parts[0] == "1" else { return nil }
            let octets = parts[1].split(separator: ":", omittingEmptySubsequences: false)
            guard octets.count == 6 else { return nil }
            var bytes: [UInt8] = []
            for octet in octets {
                guard (1 ... 2).contains(octet.count), let byte = UInt8(octet, radix: 16) else { return nil }
                bytes.append(byte)
            }
            return VPhoneMACAddress(bytes)
        }

        /// Seconds since 1970, written as `0x…` and read with `strtol(…, 0)`.
        static func expiry(_ value: String) -> Date? {
            let seconds = value.hasPrefix("0x") || value.hasPrefix("0X")
                ? Int(value.dropFirst(2), radix: 16)
                : Int(value)
            return seconds.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        }

        public func isExpired(at now: Date) -> Bool {
            expiry.map { $0 <= now } ?? false
        }
    }

    public var leases: [Lease]

    public init(leases: [Lease]) {
        self.leases = leases
    }

    /// Parses the file as bootpd's `PLCache_read` does, but refuses anything
    /// it would only skip over, so a file in an unexpected shape is never
    /// rewritten.
    public init(text: String) throws {
        var leases: [Lease] = []
        var current: [String]?
        var lineNumber = 0
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            lineNumber += 1
            switch line {
            case "{":
                guard current == nil else { throw VPhoneDHCPLeaseError.malformed(line: lineNumber) }
                current = []
            case "}":
                guard let lines = current else { throw VPhoneDHCPLeaseError.malformed(line: lineNumber) }
                leases.append(Lease(lines: lines))
                current = nil
            default:
                if current != nil {
                    current?.append(String(line))
                } else if !line.allSatisfy({ $0 == " " || $0 == "\t" }) {
                    throw VPhoneDHCPLeaseError.malformed(line: lineNumber)
                }
            }
        }
        guard current == nil else { throw VPhoneDHCPLeaseError.malformed(line: lineNumber) }
        self.leases = leases
    }

    /// The file as bootpd's `PLCache_write` would write these entries.
    public var text: String {
        leases.map { (["{"] + $0.lines + ["}"]).joined(separator: "\n") + "\n" }.joined()
    }
}

// MARK: - Errors

public enum VPhoneDHCPLeaseError: Error, Equatable {
    case malformed(line: Int)
    case changedWhileWriting
    case io(operation: String, path: String, code: Int32)
}

extension VPhoneDHCPLeaseError: CustomStringConvertible, LocalizedError {
    public var description: String {
        switch self {
        case let .malformed(line):
            "\(VPhoneDHCPLeaseList.path) is not in the format bootpd writes (line \(line)). Nothing was changed."
        case .changedWhileWriting:
            "bootpd kept changing \(VPhoneDHCPLeaseList.path) while it was being rewritten. Nothing was changed. Try again."
        case let .io(operation, path, code):
            "Unable to \(operation) \(path): \(String(cString: strerror(code)))."
        }
    }

    public var errorDescription: String? {
        description
    }
}

// MARK: - Audit

/// Who each lease on the shared network belongs to, against the MACs of the
/// machines in one or more libraries.
public struct VPhoneDHCPLeaseAudit: Sendable {
    public enum Owner: Equatable, Sendable {
        /// The current MAC of this machine.
        case machine(String)
        /// Off the shared network, or a client that is not an iOS or iPadOS
        /// guest: another VM app, or a device on Internet Sharing.
        case foreign
        /// A guest no machine claims, still inside its lease. A machine that
        /// is running while its MAC is replaced keeps its old one until it
        /// stops, so a live lease is never released.
        case active
        /// A guest no machine claims, past its lease: nobody is using the
        /// address, and only this entry keeps bootpd from handing it out.
        case orphan
    }

    public struct Entry: Equatable, Sendable {
        public let lease: VPhoneDHCPLeaseList.Lease
        public let owner: Owner
    }

    /// The device types an iOS or iPadOS guest sends as its DHCP host name
    /// (`get_device_type` in IPConfiguration, used whenever the network is
    /// private). Every vphone guest is one of these.
    public static let guestHostNames: Set<String> = ["iPhone", "iPad"]

    public let entries: [Entry]

    public init(
        _ list: VPhoneDHCPLeaseList,
        machines: [VPhoneMACAddress: String],
        sharedSubnet: VPhoneIPv4Subnet,
        now: Date = Date(),
    ) {
        entries = list.leases.map { lease in
            let owner: Owner = if let mac = lease.hardwareAddress, let name = machines[mac] {
                .machine(name)
            } else if lease.hardwareAddress == nil
                || !(lease.address.map(sharedSubnet.contains) ?? false)
                || !Self.guestHostNames.contains(lease.name ?? "")
            {
                .foreign
            } else if !lease.isExpired(at: now) {
                .active
            } else {
                .orphan
            }
            return Entry(lease: lease, owner: owner)
        }
    }

    public var orphans: [VPhoneDHCPLeaseList.Lease] {
        entries.filter { $0.owner == .orphan }.map(\.lease)
    }

    /// The machines' MACs, keyed for the audit. A machine with no saved MAC
    /// gets a new one at its next launch, so it claims nothing.
    public static func machineMACs(_ bundles: [VPhoneBundle]) -> [VPhoneMACAddress: String] {
        var macs: [VPhoneMACAddress: String] = [:]
        for bundle in bundles {
            guard let mac = VPhoneMACAddress(string: bundle.manifest.networkConfig.macAddress) else { continue }
            // A clone shares its original's MAC; either name will do.
            macs[mac] = macs[mac] ?? bundle.name
        }
        return macs
    }
}

// MARK: - Release

public enum VPhoneDHCPLeaseRelease {
    /// bootpd posts this whenever it changes the list; InternetSharing and
    /// anything else that shows leases reads the file again on it.
    static let changeNotification = "com.apple.bootpd.DHCPLeaseList"

    /// Rewrites the lease list without the entries `select` picks, then has
    /// a running bootpd read it again. Needs root, as the file is root's.
    ///
    /// bootpd writes the file only while it answers a client, so it can
    /// change between the read and the rename here. The file is compared
    /// before the rename and the whole pass retried if it moved; after the
    /// rename, SIGHUP makes bootpd read the file again before it answers the
    /// next client, so its in-memory list never writes a released entry back.
    @discardableResult
    public static func release(
        at path: String = VPhoneDHCPLeaseList.path,
        notifyServer: Bool = true,
        select: (VPhoneDHCPLeaseList) -> [VPhoneDHCPLeaseList.Lease],
    ) throws -> [VPhoneDHCPLeaseList.Lease] {
        for _ in 0 ..< 3 {
            let before = try status(of: path)
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let list = try VPhoneDHCPLeaseList(text: String(decoding: data, as: UTF8.self))
            let released = select(list)
            guard !released.isEmpty else { return [] }

            let kept = VPhoneDHCPLeaseList(leases: list.leases.filter { !released.contains($0) })
            let staging = path + ".vphone-\(getpid())"
            try write(kept.text, to: staging, like: before)
            guard try sameFile(status(of: path), before) else {
                unlink(staging)
                continue
            }
            guard rename(staging, path) == 0 else {
                let code = errno
                unlink(staging)
                throw VPhoneDHCPLeaseError.io(operation: "replace", path: path, code: code)
            }
            if notifyServer {
                reloadServer()
            }
            return released
        }
        throw VPhoneDHCPLeaseError.changedWhileWriting
    }

    // MARK: - Server

    /// SIGHUP to every running bootpd, and the change notification. bootpd
    /// is started on demand by launchd and exits when idle; when none is
    /// running, the next one reads the file as it starts.
    static func reloadServer() {
        for pid in processes(named: "bootpd") {
            kill(pid, SIGHUP)
        }
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(changeNotification as CFString),
            nil,
            nil,
            true,
        )
    }

    static func processes(named name: String) -> [pid_t] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(count) * 2)
        let filled = pids.withUnsafeMutableBytes {
            proc_listallpids($0.baseAddress, Int32($0.count))
        }
        guard filled > 0 else { return [] }
        return pids.prefix(Int(filled)).filter { pid in
            guard pid > 0 else { return false }
            var buffer = [CChar](repeating: 0, count: 256)
            guard proc_name(pid, &buffer, UInt32(buffer.count)) > 0 else { return false }
            return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self) == name
        }
    }

    // MARK: - Files

    private static func status(of path: String) throws -> stat {
        var info = stat()
        guard lstat(path, &info) == 0 else {
            throw VPhoneDHCPLeaseError.io(operation: "read", path: path, code: errno)
        }
        return info
    }

    private static func sameFile(_ a: stat, _ b: stat) -> Bool {
        a.st_dev == b.st_dev && a.st_ino == b.st_ino && a.st_size == b.st_size
            && a.st_mtimespec.tv_sec == b.st_mtimespec.tv_sec
            && a.st_mtimespec.tv_nsec == b.st_mtimespec.tv_nsec
    }

    /// A new file beside the list with its owner and mode, so the rename
    /// leaves the list exactly as bootpd keeps it (root:wheel 0644).
    private static func write(_ text: String, to path: String, like original: stat) throws {
        unlink(path)
        let descriptor = open(path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, original.st_mode & 0o777)
        guard descriptor >= 0 else {
            throw VPhoneDHCPLeaseError.io(operation: "create", path: path, code: errno)
        }
        defer { close(descriptor) }
        do {
            let bytes = Array(text.utf8)
            var offset = 0
            while offset < bytes.count {
                let written = bytes[offset...].withUnsafeBytes { Darwin.write(descriptor, $0.baseAddress, $0.count) }
                guard written > 0 else {
                    throw VPhoneDHCPLeaseError.io(operation: "write", path: path, code: errno)
                }
                offset += written
            }
            if geteuid() == 0, fchown(descriptor, original.st_uid, original.st_gid) != 0 {
                throw VPhoneDHCPLeaseError.io(operation: "set the owner of", path: path, code: errno)
            }
            guard fchmod(descriptor, original.st_mode & 0o777) == 0, fsync(descriptor) == 0 else {
                throw VPhoneDHCPLeaseError.io(operation: "write", path: path, code: errno)
            }
        } catch {
            unlink(path)
            throw error
        }
    }
}
