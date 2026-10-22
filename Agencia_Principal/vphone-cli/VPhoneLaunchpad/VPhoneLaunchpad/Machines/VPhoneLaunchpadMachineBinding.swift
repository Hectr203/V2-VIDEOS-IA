import Foundation

/// The Core Bundle a machine runs with, and the bundles that built the parts
/// of it a later bundle does not replace.
///
/// A machine is made of three layers that come from a bundle at different
/// times:
/// - the host programs (`vphone-cli`, `vphone-vm`), taken from `bundle` on
///   every command, so changing it takes effect on the next start;
/// - the guest environment (vphoned and the hook dylibs), copied in by
///   `cfw install` and again by `cfw update-environment`;
/// - the boot chain and the custom firmware patches, written by `fw patch`,
///   `restore` and `cfw install` when the machine is created. Only creating
///   the machine again changes them.
///
/// Launchpad keeps this in `launchpad.json` inside the machine folder, so it
/// moves with `vm rename` and is copied by `vm clone`. vphone-cli neither
/// reads nor writes it.
nonisolated struct VPhoneLaunchpadMachineBinding: Codable, Equatable, Sendable {
    /// The store version every command on this machine runs with.
    var bundle: String
    /// The bundle that patched and restored the boot chain. Nil for a
    /// machine created before Launchpad recorded it, or reverted to a
    /// snapshot Launchpad saved no binding with.
    var bootChain: String?
    /// The bundle whose guest environment was installed last. Nil while
    /// unknown, as after a revert to a snapshot with no saved binding.
    var guestEnvironment: String?

    static let fileName = "launchpad.json"

    init(bundle: String, bootChain: String? = nil, guestEnvironment: String? = nil) {
        self.bundle = bundle
        self.bootChain = bootChain
        self.guestEnvironment = guestEnvironment
    }

    /// True when the guest environment is known to come from another bundle
    /// than the host programs that talk to it.
    var hasMixedVersions: Bool {
        guestEnvironment.map { $0 != bundle } ?? false
    }

    // MARK: - File

    static func url(for machine: VPhoneLaunchpadMachinePath) -> URL {
        machine.url.appendingPathComponent(fileName)
    }

    /// Nil when the machine has no binding yet, or the file is not one
    /// Launchpad wrote. Every version is checked, since the file is in a
    /// folder the user owns and a version becomes a path in the store.
    static func load(_ machine: VPhoneLaunchpadMachinePath) -> VPhoneLaunchpadMachineBinding? {
        load(from: url(for: machine))
    }

    private static func load(from url: URL) -> VPhoneLaunchpadMachineBinding? {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
              values.isRegularFile == true, values.isSymbolicLink != true,
              let data = try? Data(contentsOf: url),
              let binding = try? JSONDecoder().decode(Self.self, from: data),
              VPhoneLaunchpadNames.isValidVersion(binding.bundle),
              [binding.bootChain, binding.guestEnvironment].allSatisfy({ $0.map(VPhoneLaunchpadNames.isValidVersion) ?? true })
        else {
            return nil
        }
        return binding
    }

    /// Atomic, so a `launchpad.json` that is a symbolic link is replaced
    /// rather than written through.
    func save(to machine: VPhoneLaunchpadMachinePath) throws {
        try write(to: Self.url(for: machine))
    }

    private func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }

    // MARK: - Snapshots

    /// A snapshot (`vm snapshot create`) copies the disk, the SEP storage and
    /// the NVRAM, and leaves `launchpad.json` alone: vphone-cli never reads
    /// it. Launchpad keeps a copy of the binding as it was beside the
    /// snapshot's files, in `Snapshots/<name>/launchpad.json`, which
    /// vphone-cli keeps with the snapshot and deletes with it.
    ///
    /// Nil for a name that is not one path component vphone-cli accepts, or
    /// when `Snapshots` or the snapshot's folder is anything but a real
    /// directory, so the copy is never written or read through a link.
    static func url(for machine: VPhoneLaunchpadMachinePath, snapshot name: String) -> URL? {
        guard VPhoneLaunchpadNames.isValidMachineName(name) else {
            return nil
        }
        let snapshots = machine.url.appendingPathComponent("Snapshots", isDirectory: true)
        let folder = snapshots.appendingPathComponent(name, isDirectory: true)
        for directory in [snapshots, folder] {
            guard let values = try? directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  values.isDirectory == true, values.isSymbolicLink != true
            else {
                return nil
            }
        }
        return folder.appendingPathComponent(fileName)
    }

    /// The binding saved with a snapshot, checked as `load` checks a
    /// machine's own.
    static func load(_ machine: VPhoneLaunchpadMachinePath, snapshot name: String) -> VPhoneLaunchpadMachineBinding? {
        url(for: machine, snapshot: name).flatMap(load(from:))
    }

    func save(to machine: VPhoneLaunchpadMachinePath, snapshot name: String) throws {
        guard let url = Self.url(for: machine, snapshot: name) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [
                NSFilePathErrorKey: machine.url.appendingPathComponent("Snapshots").appendingPathComponent(name).path,
            ])
        }
        try write(to: url)
    }

    /// This binding after its machine is reverted to a snapshot, given the
    /// binding saved with it. The guest environment and the boot chain live
    /// on the disk and in the NVRAM the revert put back, so they are
    /// whatever they were when the snapshot was taken: the saved ones, or
    /// unknown when nothing readable was saved (a snapshot taken with
    /// vphone-cli), never the ones the machine had before the revert. The
    /// host programs are not part of the machine's files: the bundle stays
    /// the one chosen now.
    func reverted(to saved: VPhoneLaunchpadMachineBinding?) -> VPhoneLaunchpadMachineBinding {
        VPhoneLaunchpadMachineBinding(
            bundle: bundle,
            bootChain: saved?.bootChain,
            guestEnvironment: saved?.guestEnvironment,
        )
    }
}
