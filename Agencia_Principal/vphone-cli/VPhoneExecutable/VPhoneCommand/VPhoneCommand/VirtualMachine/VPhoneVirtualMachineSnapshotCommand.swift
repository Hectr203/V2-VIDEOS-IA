import ArgumentParser
import Foundation
import VPhoneCoreKit

// MARK: - snapshot

/// `vm snapshot`: save and restore a stopped machine's disk, SEP and NVRAM
/// together. Launchpad drives these verbs and reads `list --json`, so their
/// arguments and output are a contract with it.
struct VPhoneVirtualMachineSnapshotCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "snapshot",
        abstract: "Save a stopped VM's disk state, and revert to it later",
        discussion: """
        A snapshot holds the disk image, SEPStorage and nvram.bin from one moment, plus the \
        records that describe them (PatchReceipt.plist, restore-info.json). They are APFS \
        clones in <vm>/Snapshots/<name>/, so a snapshot costs no space until the VM writes \
        to its disk, and the VM must be on an APFS volume.

        The VM must be stopped to take or revert to a snapshot: the SEP's state and the \
        disk advance together, and a mismatched pair panics the guest.

        config.plist is not part of a snapshot: the VM keeps its identity, CPU, memory, \
        network and settings across a revert. vm export and vm clone leave snapshots behind.
        """,
        subcommands: [
            VPhoneVirtualMachineSnapshotCreateCommand.self,
            VPhoneVirtualMachineSnapshotListCommand.self,
            VPhoneVirtualMachineSnapshotRevertCommand.self,
            VPhoneVirtualMachineSnapshotDeleteCommand.self,
        ],
    )

    /// Local time, to the second: what `list` shows a person.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static func describe(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func confirm(_ question: String) -> Bool {
        print("\(question) [y/N] ", terminator: "")
        return (readLine() ?? "").lowercased() == "y"
    }
}

// MARK: - create

struct VPhoneVirtualMachineSnapshotCreateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Take a snapshot of a stopped VM",
    )

    @OptionGroup var lib: VPhoneLibraryOption
    @Argument(help: "VM name") var vm: String
    @Argument(help: "Snapshot name") var name: String
    @Option(name: .long, help: "A note to keep with the snapshot") var note: String?

    func run() throws {
        let bundle = try lib.library.bundle(named: vm)
        let snapshot = try VPhoneMachineSnapshots.create(name, note: note, of: bundle)
        print("created snapshot '\(snapshot.name)' of \(bundle.name)")
    }
}

// MARK: - list

struct VPhoneVirtualMachineSnapshotListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List a VM's snapshots, oldest first",
    )

    /// One `--json` element. A missing note is left out of the object.
    struct Entry: Encodable {
        let name: String
        let created: Date
        let note: String?
    }

    @OptionGroup var lib: VPhoneLibraryOption
    @Argument(help: "VM name") var vm: String
    @Flag(name: .shortAndLong, help: "Emit JSON") var json = false

    func run() throws {
        let bundle = try lib.library.bundle(named: vm)
        let snapshots = try VPhoneMachineSnapshots.list(of: bundle)
        if json {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            let entries = snapshots.map { Entry(name: $0.name, created: $0.created, note: $0.note) }
            try print(String(decoding: encoder.encode(entries), as: UTF8.self))
            return
        }
        guard !snapshots.isEmpty else {
            print("No snapshots of \(bundle.name). Take one with vm snapshot create \(bundle.name) <name>.")
            return
        }
        let width = max(4, snapshots.map(\.name.count).max() ?? 0)
        print("NAME".padding(toLength: width, withPad: " ", startingAt: 0) + "  CREATED              NOTE")
        for snapshot in snapshots {
            let name = snapshot.name.padding(toLength: width, withPad: " ", startingAt: 0)
            let created = VPhoneVirtualMachineSnapshotCommand.describe(snapshot.created)
            print("\(name)  \(created)  \(snapshot.note ?? "")")
        }
    }
}

// MARK: - revert

struct VPhoneVirtualMachineSnapshotRevertCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "revert",
        abstract: "Put a stopped VM back to a snapshot; the snapshot is kept",
    )

    @OptionGroup var lib: VPhoneLibraryOption
    @Argument(help: "VM name") var vm: String
    @Argument(help: "Snapshot name") var name: String
    @Flag(name: .shortAndLong, help: "Do not prompt") var force = false

    func run() throws {
        let bundle = try lib.library.bundle(named: vm)
        let snapshot = try VPhoneMachineSnapshots.snapshot(named: name, of: bundle)
        if !force {
            // Refuse before asking, not after; revert checks again itself.
            try VPhoneBundleActivity.requireStopped(bundle)
            let taken = VPhoneVirtualMachineSnapshotCommand.describe(snapshot.created)
            guard VPhoneVirtualMachineSnapshotCommand.confirm(
                "Revert '\(bundle.name)' to snapshot '\(snapshot.name)' from \(taken)? Everything the VM wrote since is lost.",
            ) else {
                print("Canceled. Nothing was changed.")
                return
            }
        }
        try VPhoneMachineSnapshots.revert(to: name, of: bundle)
        print("reverted \(bundle.name) to snapshot '\(snapshot.name)'")
    }
}

// MARK: - delete

struct VPhoneVirtualMachineSnapshotDeleteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete a snapshot",
    )

    @OptionGroup var lib: VPhoneLibraryOption
    @Argument(help: "VM name") var vm: String
    @Argument(help: "Snapshot name") var name: String
    @Flag(name: .shortAndLong, help: "Do not prompt") var force = false

    func run() throws {
        let bundle = try lib.library.bundle(named: vm)
        _ = try VPhoneMachineSnapshots.folder(named: name, of: bundle)
        if !force {
            guard VPhoneVirtualMachineSnapshotCommand.confirm(
                "Delete snapshot '\(name)' of '\(bundle.name)'?",
            ) else {
                print("Canceled. Nothing was deleted.")
                return
            }
        }
        try VPhoneMachineSnapshots.delete(name, of: bundle)
        print("deleted snapshot '\(name)' of \(bundle.name)")
    }
}
