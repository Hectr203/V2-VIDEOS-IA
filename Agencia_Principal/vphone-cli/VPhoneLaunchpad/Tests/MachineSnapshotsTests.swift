import Foundation

@main
struct MachineSnapshotsTests {
    static func main() throws {
        try snapshotList()
        defaultNames()
        arguments()
        try bindingSidecar()
    }

    // MARK: - vm snapshot list --json

    static func snapshotList() throws {
        // The shape `vm snapshot list --json` prints: one line, keys sorted,
        // `.iso8601` dates, no `note` when there is none.
        let json = #"[{"created":"2026-10-06T14:30:00Z","name":"fresh","note":"before frida"},{"created":"2026-10-06T15:00:00Z","name":"second"}]"#
        let snapshots = try VPhoneLaunchpadMachineSnapshot.list(from: Data(json.utf8))
        precondition(snapshots.map(\.name) == ["fresh", "second"], "The list keeps the CLI's order")
        precondition(snapshots[0].note == "before frida", "A note is read")
        precondition(snapshots[1].note == nil, "A missing note is nil")
        precondition(snapshots[0].created == Date(timeIntervalSince1970: 1_791_297_000), "created is \(snapshots[0].created)")
        precondition(snapshots[0].id == "fresh", "A snapshot is identified by its name")

        let empty = try VPhoneLaunchpadMachineSnapshot.list(from: Data("[]".utf8))
        precondition(empty.isEmpty, "An empty list decodes")

        for bad in [
            #"[{"created":"yesterday","name":"x"}]"#,
            #"[{"created":"2026-10-06T14:30:00Z"}]"#,
            #"{"name":"x"}"#,
        ] {
            precondition((try? VPhoneLaunchpadMachineSnapshot.list(from: Data(bad.utf8))) == nil, "Rejected list: \(bad)")
        }

        // Through the same path `vm list` takes: warnings on stderr come first
        // in the merged output, and the document is the last line opening one.
        let result = VPhoneLaunchpadCommandResult(status: 0, lines: ["warning: something", json])
        let afterWarning = try VPhoneLaunchpadMachineSnapshot.list(from: result.jsonData!)
        precondition(afterWarning.count == 2, "JSON after a warning line")
        print("Snapshot list tests passed")
    }

    // MARK: - Default names

    static func defaultNames() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let date = Date(timeIntervalSince1970: 1_791_297_000) // 22:30 in Shanghai
        let name = VPhoneLaunchpadMachineSnapshot.defaultName(at: date, taken: [], calendar: calendar)
        precondition(name == "2026-10-06-2230", "Default name is \(name)")
        precondition(VPhoneLaunchpadNames.isValidMachineName(name), "The default name follows the name rules")
        let next = VPhoneLaunchpadMachineSnapshot.defaultName(at: date, taken: ["2026-10-06-2230", "2026-10-06-2230-2"], calendar: calendar)
        precondition(next == "2026-10-06-2230-3", "A taken name gains a counter: \(next)")
        print("Snapshot default name tests passed")
    }

    // MARK: - Arguments

    static func arguments() {
        let machine = VPhoneLaunchpadMachinePath(libraryRoot: "/Volumes/Lab/machines", name: "frida-lab")
        let library = ["--library-root", "/Volumes/Lab/machines"]

        precondition(machine.cloneArguments(as: "frida-lab-clone", newIdentity: true)
            == ["vm", "clone", "frida-lab", "frida-lab-clone", "--new-identity"] + library, "Clone with a new identity")
        precondition(machine.cloneArguments(as: "frida-lab-clone", newIdentity: false)
            == ["vm", "clone", "frida-lab", "frida-lab-clone"] + library, "Clone as the same device")

        precondition(machine.snapshotListArguments == ["vm", "snapshot", "list", "frida-lab", "--json"] + library, "List")
        precondition(machine.snapshotCreateArguments("fresh", note: nil)
            == ["vm", "snapshot", "create", "frida-lab", "fresh"] + library, "Create without a note")
        precondition(machine.snapshotCreateArguments("fresh", note: "  \n ")
            == ["vm", "snapshot", "create", "frida-lab", "fresh"] + library, "A blank note is left out")
        precondition(machine.snapshotCreateArguments("fresh", note: " -before frida ")
            == ["vm", "snapshot", "create", "frida-lab", "fresh", "--note=-before frida"] + library,
            "A note is trimmed and joined to its option")
        precondition(machine.snapshotRevertArguments("fresh")
            == ["vm", "snapshot", "revert", "frida-lab", "fresh", "--force"] + library, "Revert")
        precondition(machine.snapshotDeleteArguments("fresh")
            == ["vm", "snapshot", "delete", "frida-lab", "fresh", "--force"] + library, "Delete")
        print("Clone and snapshot argument tests passed")
    }

    // MARK: - Binding saved with a snapshot

    static func bindingSidecar() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("machine-snapshots-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        let machine = VPhoneLaunchpadMachinePath(libraryRoot: root.path, name: "research-01")
        let snapshots = machine.url.appendingPathComponent("Snapshots", isDirectory: true)
        try fileManager.createDirectory(at: machine.url, withIntermediateDirectories: true)

        let taken = VPhoneLaunchpadMachineBinding(bundle: "2.7.0", bootChain: "2.6.0", guestEnvironment: "2.6.1")

        // vphone-cli makes the folder; without it nothing is written.
        precondition(VPhoneLaunchpadMachineBinding.url(for: machine, snapshot: "fresh") == nil, "No folder, no sidecar")
        precondition((try? taken.save(to: machine, snapshot: "fresh")) == nil, "Saving needs the snapshot's folder")

        try fileManager.createDirectory(at: snapshots.appendingPathComponent("fresh"), withIntermediateDirectories: true)
        try taken.save(to: machine, snapshot: "fresh")
        let sidecar = snapshots.appendingPathComponent("fresh/launchpad.json")
        precondition(fileManager.fileExists(atPath: sidecar.path), "The binding is saved in the snapshot's folder")
        precondition(VPhoneLaunchpadMachineBinding.load(machine, snapshot: "fresh") == taken, "The saved binding loads back")
        precondition(VPhoneLaunchpadMachineBinding.load(machine) == nil, "The machine's own binding is untouched")

        // After the revert: boot chain and guest environment from the
        // snapshot, the bundle chosen now.
        let current = VPhoneLaunchpadMachineBinding(bundle: "2.7.1-local.ab12cd34", bootChain: "2.7.0", guestEnvironment: "2.7.1-local.ab12cd34")
        let reverted = current.reverted(to: taken)
        precondition(reverted == VPhoneLaunchpadMachineBinding(bundle: "2.7.1-local.ab12cd34", bootChain: "2.6.0", guestEnvironment: "2.6.1"),
                     "Reverted binding: \(reverted)")
        precondition(reverted.hasMixedVersions, "The older guest environment shows as mixed")
        // A snapshot from before Launchpad knew the guest environment leaves it unknown.
        precondition(current.reverted(to: VPhoneLaunchpadMachineBinding(bundle: "2.7.0")).guestEnvironment == nil,
                     "An unknown guest environment stays unknown")
        // A snapshot with no saved binding (taken with vphone-cli, or the
        // copy was not written) makes both unknown rather than keeping the
        // newer ones the revert just replaced; the bundle stays.
        let unsaved = current.reverted(to: nil)
        precondition(unsaved == VPhoneLaunchpadMachineBinding(bundle: "2.7.1-local.ab12cd34"), "Reverted without a saved binding: \(unsaved)")
        precondition(!unsaved.hasMixedVersions, "An unknown guest environment is not claimed to match or differ")
        precondition(VPhoneLaunchpadMachineBinding.load(machine, snapshot: "missing") == nil, "A snapshot with no folder has no saved binding")
        precondition(current.reverted(to: VPhoneLaunchpadMachineBinding.load(machine, snapshot: "fresh")) == reverted,
                     "A readable saved binding still supplies the boot chain and guest environment")

        // The sidecar is checked like the machine's own binding.
        try Data(#"{"bundle":"2.7.0","guestEnvironment":"../evil"}"#.utf8).write(to: sidecar)
        precondition(VPhoneLaunchpadMachineBinding.load(machine, snapshot: "fresh") == nil, "An invalid sidecar is rejected")
        precondition(current.reverted(to: VPhoneLaunchpadMachineBinding.load(machine, snapshot: "fresh")) == unsaved,
                     "An unreadable saved binding counts as none")

        // Names outside the rules, and folders that are links, are refused.
        for name in ["", ".", "..", "../research-02", "a/b", ".hidden"] {
            precondition(VPhoneLaunchpadMachineBinding.url(for: machine, snapshot: name) == nil, "Rejected snapshot name: \(name)")
        }
        let elsewhere = root.appendingPathComponent("elsewhere", isDirectory: true)
        try fileManager.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        try fileManager.createSymbolicLink(at: snapshots.appendingPathComponent("linked"), withDestinationURL: elsewhere)
        precondition(VPhoneLaunchpadMachineBinding.url(for: machine, snapshot: "linked") == nil, "A linked snapshot folder is refused")
        precondition((try? taken.save(to: machine, snapshot: "linked")) == nil, "Nothing is written through a linked folder")
        precondition(!fileManager.fileExists(atPath: elsewhere.appendingPathComponent("launchpad.json").path), "The link's target is untouched")

        let otherMachine = VPhoneLaunchpadMachinePath(libraryRoot: root.path, name: "research-02")
        try fileManager.createDirectory(at: otherMachine.url, withIntermediateDirectories: true)
        try fileManager.createSymbolicLink(at: otherMachine.url.appendingPathComponent("Snapshots"), withDestinationURL: snapshots)
        precondition(VPhoneLaunchpadMachineBinding.url(for: otherMachine, snapshot: "fresh") == nil, "A linked Snapshots folder is refused")
        print("Snapshot binding tests passed: save, load, revert, invalid sidecar, names, links")
    }
}
