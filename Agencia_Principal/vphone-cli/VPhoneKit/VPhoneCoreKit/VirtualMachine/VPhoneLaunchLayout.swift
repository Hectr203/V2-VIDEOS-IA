import Foundation

// MARK: - VPhoneLaunchLayout

public struct VPhoneLaunchLayout: Sendable {
    public let resources: VPhoneResources

    public init(resources: VPhoneResources) {
        self.resources = resources
    }

    public init(projectRoot: URL) {
        self.init(resources: VPhoneResources(base: projectRoot))
    }

    public var vphoned: URL {
        resources.vphoned
    }

    /// Copy the built vphoned into the bundle if present and different.
    @discardableResult
    public func stageVphoned(into bundle: VPhoneBundle) throws -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: vphoned.path) else {
            throw VPhoneGuestBinaries.Error.missing("vphoned.signed", [vphoned])
        }
        let dst = bundle.url.appendingPathComponent(".vphoned.signed")
        if fm.fileExists(atPath: dst.path),
           let a = try? Data(contentsOf: vphoned, options: .mappedIfSafe),
           let b = try? Data(contentsOf: dst, options: .mappedIfSafe), a == b
        {
            return false
        }
        if fm.fileExists(atPath: dst.path) {
            try fm.removeItem(at: dst)
        }
        try fm.copyItem(at: vphoned, to: dst)
        try VPhoneHostFilePermissions.makeAccessible(at: dst)
        return true
    }
}

// MARK: - VPhoneLsof

public enum VPhoneLsof {
    public static func parsePIDs(_ output: String) -> [Int32] {
        var seen = Set<Int32>()
        var pids: [Int32] = []
        for line in output.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let pid = Int32(trimmed), !seen.contains(pid) else { continue }
            seen.insert(pid)
            pids.append(pid)
        }
        return pids.sorted()
    }
}

// MARK: - VPhoneProcessHolder

/// A process that has one of a machine's files open, and what it is, judged
/// by its executable.
///
/// Many processes open a machine's `Disk.img` without running it: Launchpad's
/// disk meter maps its extents for a moment every half minute, Spotlight and
/// backup tools read it, and `vm template trim` or a rebase attach it. Only two
/// kinds of process run a machine: `vphone-vm` (from any copy of the bundle)
/// and Virtualization's VM service, which holds the disk for it. Those are the
/// only ones `vm stop` may signal; every other holder is reported by name.
public struct VPhoneProcessHolder: Equatable, Sendable, CustomStringConvertible {
    public enum Kind: Equatable, Sendable {
        /// `vphone-vm`, which runs the machine.
        case virtualMachine
        /// `com.apple.Virtualization.VirtualMachine`, the XPC service that
        /// holds the machine's disk for its `vphone-vm`.
        case virtualizationService
        /// Anything else that has the file open.
        case other
    }

    public var pid: pid_t
    /// From `proc_pidpath`; nil for a process that is gone or cannot be
    /// inspected.
    public var executablePath: String?

    public init(pid: pid_t, executablePath: String?) {
        self.pid = pid
        self.executablePath = executablePath
    }

    /// Looks the executable up now.
    public init(pid: pid_t) {
        self.init(pid: pid, executablePath: Self.executablePath(of: pid))
    }

    public var kind: Kind {
        Self.kind(executablePath: executablePath)
    }

    /// Whether this process runs a machine, and may be stopped as one.
    public var runsMachine: Bool {
        kind != .other
    }

    /// The executable's file name, or `unknown`.
    public var name: String {
        executablePath.map { ($0 as NSString).lastPathComponent } ?? "unknown"
    }

    public var description: String {
        "\(pid) \(name)"
    }

    static let virtualizationServiceName = "com.apple.Virtualization.VirtualMachine"

    /// What an executable path is. `vphone-vm` counts from any folder: every
    /// installed bundle has its own copy. The VM service counts only from
    /// inside Virtualization.framework, so another program that takes its name
    /// is still `other`.
    ///
    /// Launchpad, which does not link this kit, judges the holders its own
    /// `lsof` finds with a copy (`VPhoneLaunchpadDiskHolder.runsMachine`).
    /// Both are tested against `VPhoneCoreKitTests/VirtualMachine/
    /// ProcessHolderKinds.json`: change the table and both copies together.
    public static func kind(executablePath: String?) -> Kind {
        guard let executablePath, !executablePath.isEmpty else { return .other }
        let components = (executablePath as NSString).pathComponents
        switch components.last {
        case "vphone-vm":
            return .virtualMachine
        case virtualizationServiceName where components.contains("Virtualization.framework"):
            return .virtualizationService
        default:
            return .other
        }
    }

    /// Splits holders into the ones that run a machine and the rest, each in
    /// PID order.
    public static func classify(_ holders: [VPhoneProcessHolder]) -> (machine: [VPhoneProcessHolder], others: [VPhoneProcessHolder]) {
        let sorted = holders.sorted { $0.pid < $1.pid }
        return (sorted.filter(\.runsMachine), sorted.filter { !$0.runsMachine })
    }

    /// `123 vphone-vm, 456 mds_stores`.
    public static func describe(_ holders: [VPhoneProcessHolder]) -> String {
        holders.map(\.description).joined(separator: ", ")
    }

    /// Why an operation that needs a machine's disk to itself (`cfw install`
    /// and its variants) refuses, or nil when `holders` is empty. Every holder
    /// refuses; the wording says whether one of them runs the machine.
    /// `rerun` completes "…, then <rerun>.", for example "run cfw install again".
    public static func diskRefusal(_ holders: [VPhoneProcessHolder], rerun: String) -> String? {
        guard !holders.isEmpty else { return nil }
        let (machine, others) = classify(holders)
        if !machine.isEmpty {
            return "The VM is running (process \(describe(machine + others))). Stop the VM, then \(rerun)."
        }
        return "The VM disk is open in process \(describe(others)), which does not run the VM. "
            + "Wait for it to close the disk, then \(rerun)."
    }

    public static func executablePath(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(4 * MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}

// MARK: - VPhoneGuestProcesses

/// Finds the `vphone-vm` that runs one machine.
///
/// The disk image is held open only by Virtualization's own XPC service, not
/// by `vphone-vm`, so the processes `lsof` names for it are the wrong ones to
/// stop: a SIGINT ends the service, and `vphone-vm` then sees its machine stop
/// with an error. `vphone-vm` is told which machine to run by `--config`, and
/// that argument is how it is found here.
public enum VPhoneGuestProcesses {
    /// Every `vphone-vm` of this user whose `--config` is `config`, compared
    /// after resolving symbolic links on both sides.
    public static func virtualMachinePIDs(config: URL) -> [Int32] {
        let target = config.resolvingSymlinksInPath().standardizedFileURL.path
        return allPIDs().filter { pid in
            guard pid != getpid(), let arguments = arguments(of: pid) else { return false }
            return runsMachine(arguments, configPath: target)
        }
    }

    /// Whether an argument vector is a `vphone-vm` started with `--config`
    /// at `configPath` (already resolved and standardized).
    static func runsMachine(_ arguments: [String], configPath: String) -> Bool {
        guard let executable = arguments.first,
              (executable as NSString).lastPathComponent == "vphone-vm"
        else { return false }
        for (index, argument) in arguments.enumerated().dropFirst() {
            let value: String
            if argument == "--config", index + 1 < arguments.count {
                value = arguments[index + 1]
            } else if argument.hasPrefix("--config=") {
                value = String(argument.dropFirst("--config=".count))
            } else {
                continue
            }
            let path = URL(fileURLWithPath: value).resolvingSymlinksInPath().standardizedFileURL.path
            return path == configPath
        }
        return false
    }

    /// The argument vector in a `KERN_PROCARGS2` buffer: a 32-bit `argc`,
    /// the executable path, NUL padding, then `argc` NUL-terminated strings.
    static func parseProcessArguments(_ buffer: [UInt8]) -> [String]? {
        guard buffer.count >= MemoryLayout<Int32>.size else { return nil }
        let argc = buffer.withUnsafeBytes { Int($0.loadUnaligned(as: Int32.self)) }
        guard argc > 0 else { return nil }
        var index = MemoryLayout<Int32>.size
        // Skip the executable path, then the padding after it.
        while index < buffer.count, buffer[index] != 0 {
            index += 1
        }
        while index < buffer.count, buffer[index] == 0 {
            index += 1
        }
        var arguments: [String] = []
        while arguments.count < argc, index < buffer.count {
            let start = index
            while index < buffer.count, buffer[index] != 0 {
                index += 1
            }
            arguments.append(String(decoding: buffer[start ..< index], as: UTF8.self))
            index += 1
        }
        return arguments.count == argc ? arguments : nil
    }

    static func allPIDs() -> [Int32] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        // Room for processes started between the two calls.
        var pids = [Int32](repeating: 0, count: Int(count) + 64)
        let filled = pids.withUnsafeMutableBytes {
            proc_listallpids($0.baseAddress, Int32($0.count))
        }
        guard filled > 0 else { return [] }
        return Array(pids.prefix(Int(filled))).filter { $0 > 0 }
    }

    /// Nil for a process that is gone or belongs to another user.
    private static func arguments(of pid: Int32) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }
        return parseProcessArguments(Array(buffer.prefix(size)))
    }
}
