import Darwin
import Foundation

/// A process other than Launchpad that `lsof` lists for a machine's disk
/// image, and whether it runs the machine, judged by its executable.
///
/// Many processes open a disk image without running it: `tail`, Spotlight, a
/// backup tool, a `vm template trim` attaching it. Only `vphone-vm` (from any
/// copy of the bundle) and Virtualization's VM service, which holds the disk
/// for it, make a machine running. This is the CLI's `VPhoneProcessHolder`
/// (VPhoneCoreKit, which Launchpad does not link), and the two must judge a
/// path the same way: `vm stop` signals only the holders the CLI calls VM
/// processes, and Launchpad offers Stop only for a machine it calls running.
///
/// The rule is copied rather than asked of `vphone-cli`: Launchpad runs
/// `lsof` itself on every refresh, while waiting for a stop and before an
/// operation that needs the disk, and leaves its own meter out by PID. Both
/// copies are tested against one table,
/// `VPhoneKit/VPhoneCoreKitTests/VirtualMachine/ProcessHolderKinds.json`
/// (`Tests/TemplatesTests.sh` here, `LaunchLayoutTests` there), so neither
/// can change alone. See Research/Host/machine_templates.md.
nonisolated struct VPhoneLaunchpadDiskHolder: Hashable, Sendable, CustomStringConvertible {
    var pid: pid_t
    /// From `proc_pidpath`; nil for a process that is gone or cannot be
    /// inspected.
    var executablePath: String?

    /// Whether this process runs a machine. A path that only takes the name of
    /// the VM service, outside Virtualization.framework, does not.
    var runsMachine: Bool {
        guard let executablePath, !executablePath.isEmpty else { return false }
        let components = (executablePath as NSString).pathComponents
        switch components.last {
        case "vphone-vm":
            return true
        case "com.apple.Virtualization.VirtualMachine":
            return components.contains("Virtualization.framework")
        default:
            return false
        }
    }

    /// The executable's file name, or `unknown`.
    var name: String {
        executablePath.map { ($0 as NSString).lastPathComponent } ?? "unknown"
    }

    /// `12925 tail`, as the CLI names a holder.
    var description: String {
        "\(pid) \(name)"
    }

    /// `410 vphone-vm, 12925 tail`.
    static func describe(_ holders: [VPhoneLaunchpadDiskHolder]) -> String {
        holders.map(\.description).joined(separator: ", ")
    }

    static func executablePath(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(4 * MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// The processes `lsof -F pn` lists for each disk in `diskOwners`, by the
    /// owner of that disk and in PID order. Launchpad itself (`excluding`)
    /// holds a disk only while its meter maps the extents, and is left out.
    static func holders<Owner: Hashable>(
        lsofOutput output: String,
        diskOwners: [String: Owner],
        excluding ownProcess: pid_t,
        executablePath: (pid_t) -> String? = Self.executablePath(of:),
    ) -> [Owner: [VPhoneLaunchpadDiskHolder]] {
        var pids: [Owner: Set<pid_t>] = [:]
        var process: pid_t?
        for line in output.split(separator: "\n") {
            if line.hasPrefix("p") {
                process = pid_t(line.dropFirst())
            } else if line.hasPrefix("n"), let process, process != ownProcess,
                      let owner = diskOwners[String(line.dropFirst())]
            {
                pids[owner, default: []].insert(process)
            }
        }
        // Each process is looked up once, however many disks it holds.
        var paths: [pid_t: String] = [:]
        for pid in Set(pids.values.joined()) {
            paths[pid] = executablePath(pid)
        }
        return pids.mapValues { held in
            held.sorted().map { VPhoneLaunchpadDiskHolder(pid: $0, executablePath: paths[$0]) }
        }
    }
}
