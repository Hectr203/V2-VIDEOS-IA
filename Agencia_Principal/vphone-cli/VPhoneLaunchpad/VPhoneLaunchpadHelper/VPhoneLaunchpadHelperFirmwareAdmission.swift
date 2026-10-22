import Darwin

/// Which CFW installs and updates may run side by side: one per machine, and
/// on a volume that running operations already write to, only while it has
/// free space for all of them.
///
/// Each run host-mounts its machine's disk, so two on one machine would
/// collide. Runs on different machines keep their own work folders, clones
/// and mount points; what they share is free space on the volumes they write
/// to.
enum VPhoneLaunchpadHelperFirmwareAdmission {
    /// A machine, named by its folder rather than its name: two libraries can
    /// each hold a machine with the same name.
    struct MachineKey: Hashable {
        let device: dev_t
        let inode: ino_t
    }

    /// The free space one run needs on each volume it writes to, matching
    /// `VPhoneCustomFirmwareInstaller.requireFreeSpace` in vphone-cli.
    static let freeSpacePerRun: Int64 = 50 * 1024 * 1024 * 1024

    static let machineBusy = "A CFW install or environment update is already running on this machine. Wait for it to finish, then try again."
    static let notEnoughSpace = "Not enough free disk space to run this alongside the CFW installs or environment updates already running. Wait for them to finish or free up space, then try again."

    /// Why a run on `machine`, writing to `volumes` (each device with a path
    /// on it), may not start beside `running` (each running machine with the
    /// devices it writes to), or nil.
    ///
    /// A volume no other run writes to is left to vphone-cli, whose own check
    /// says exactly how much space is missing. A volume shared with running
    /// operations must hold their share each plus this one's, or they could
    /// all pass their own checks and then fill the disk together.
    static func refusal(
        machine: MachineKey,
        volumes: [dev_t: String],
        running: [MachineKey: Set<dev_t>],
        availableCapacity: (String) -> Int64,
    ) -> String? {
        guard running[machine] == nil else {
            return machineBusy
        }
        for (device, path) in volumes {
            let sharing = running.values.count(where: { $0.contains(device) })
            guard sharing > 0 else { continue }
            guard availableCapacity(path) >= freeSpacePerRun * Int64(sharing + 1) else {
                return notEnoughSpace
            }
        }
        return nil
    }
}
