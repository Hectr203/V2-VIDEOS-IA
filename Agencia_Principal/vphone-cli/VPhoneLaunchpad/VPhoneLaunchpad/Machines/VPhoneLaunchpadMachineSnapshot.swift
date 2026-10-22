import Foundation

// MARK: - vm snapshot list

/// One entry of `vphone-cli vm snapshot list <vm> --json`: a copy of the
/// machine's disk, SEP storage and NVRAM taken while it was stopped. The list
/// comes oldest first.
nonisolated struct VPhoneLaunchpadMachineSnapshot: Decodable, Hashable, Identifiable, Sendable {
    let name: String
    let created: Date
    let note: String?

    var id: String {
        name
    }

    /// Decodes the array `vm snapshot list --json` prints, whose `created`
    /// is written with JSONEncoder's `.iso8601`.
    static func list(from data: Data) throws -> [Self] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Self].self, from: data)
    }

    /// The name Take Snapshot offers: the local date and time to the minute,
    /// `2026-10-06-2230`, with `-2`, `-3`… when that is taken. It follows the
    /// machine name rules, which snapshot names share.
    static func defaultName(at date: Date, taken: Set<String>, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let base = String(
            format: "%04d-%02d-%02d-%02d%02d",
            parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0, parts.minute ?? 0,
        )
        var name = base
        var counter = 2
        while taken.contains(name) {
            name = "\(base)-\(counter)"
            counter += 1
        }
        return name
    }
}

// MARK: - Arguments

/// The `vphone-cli` arguments for clone and snapshots, kept apart from the
/// library so they can be checked without running anything.
nonisolated extension VPhoneLaunchpadMachinePath {
    /// `--new-identity` gives the clone its own ECID, UDID and MAC, so it can
    /// run beside this machine.
    func cloneArguments(as newName: String, newIdentity: Bool) -> [String] {
        ["vm", "clone", name, newName] + (newIdentity ? ["--new-identity"] : []) + libraryArguments
    }

    var snapshotListArguments: [String] {
        ["vm", "snapshot", "list", name, "--json"] + libraryArguments
    }

    /// A blank note is left out. The note is joined to its option, so one
    /// that starts with a hyphen is not read as another option.
    func snapshotCreateArguments(_ snapshot: String, note: String?) -> [String] {
        var arguments = ["vm", "snapshot", "create", name, snapshot]
        if let note = note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            arguments.append("--note=\(note)")
        }
        return arguments + libraryArguments
    }

    func snapshotRevertArguments(_ snapshot: String) -> [String] {
        ["vm", "snapshot", "revert", name, snapshot, "--force"] + libraryArguments
    }

    func snapshotDeleteArguments(_ snapshot: String) -> [String] {
        ["vm", "snapshot", "delete", name, snapshot, "--force"] + libraryArguments
    }
}
