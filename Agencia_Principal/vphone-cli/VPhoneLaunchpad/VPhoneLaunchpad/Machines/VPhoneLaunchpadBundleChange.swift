import Foundation

/// The outcome of moving one machine to another Core Bundle, and the order of
/// its steps, kept apart from the library so a test can hold it to that order.
///
/// Updating the guest environment needs the disk to itself, so another
/// process holding the disk refuses the whole change before the binding is
/// written: a refused change leaves the machine as it was. Only an update that
/// fails once it has started leaves the two layers apart. The binding stays
/// then, since undoing it would not undo what the update already copied into
/// the guest: `bundle` names the new version while `guestEnvironment` still
/// names the bundle whose environment was installed last, as `vm list` and the
/// inspector show, and updating the guest environment again finishes the move.
nonisolated enum VPhoneLaunchpadBundleChange: Equatable, Sendable {
    /// Bound; the guest environment was not to be updated.
    case bound
    /// Bound, and the guest environment updated.
    case updated
    /// Bound, but the update of the guest environment failed.
    case boundButNotUpdated
    /// Nothing written: these processes, which do not run the machine, have
    /// its disk open.
    case refused([VPhoneLaunchpadDiskHolder])

    /// Checks the disk when the environment is to be updated, then binds,
    /// then updates. A failure to bind is thrown, with nothing else done.
    @MainActor
    static func perform(
        updatesEnvironment: Bool,
        otherDiskHolders: () async -> [VPhoneLaunchpadDiskHolder],
        bind: () throws -> Void,
        updateEnvironment: () async -> Bool,
    ) async throws -> Self {
        if updatesEnvironment {
            let others = await otherDiskHolders()
            guard others.isEmpty else {
                return .refused(others)
            }
        }
        try bind()
        guard updatesEnvironment else {
            return .bound
        }
        return await updateEnvironment() ? .updated : .boundButNotUpdated
    }
}
