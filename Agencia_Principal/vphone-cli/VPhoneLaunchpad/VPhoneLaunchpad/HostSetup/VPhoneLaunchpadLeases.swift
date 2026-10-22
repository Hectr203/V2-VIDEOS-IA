import Foundation
import Observation

/// The DHCP leases of the Mac's shared NAT network, as `vphone-cli vm leases`
/// reports them against every library Launchpad lists.
///
/// The Mac's DHCP server keeps an address bound to each guest MAC it has
/// seen, even after the lease runs out. A deleted machine, a replaced MAC,
/// or any launch from before MACs were saved leaves an address held by a MAC
/// nothing uses, and new guests climb through the range. Listing needs no
/// root; releasing goes through the helper.
@MainActor
@Observable
final class VPhoneLaunchpadLeases {
    nonisolated struct Lease: Decodable, Equatable, Sendable {
        let address: String?
        let mac: String?
        let name: String?
        /// `machine`, `active` or `orphan`; absent in a release report.
        let owner: String?
        let machine: String?
    }

    enum State: Equatable {
        case unknown
        case checking
        /// Nothing to compare against yet, with the reason.
        case unavailable(String)
        case listed
        case failed(String)
    }

    private(set) var state = State.unknown
    private(set) var leases: [Lease] = []
    private(set) var isReleasing = false
    var actionError: VPhoneLaunchpadError?

    private let bundles: VPhoneLaunchpadCoreBundle
    private let machines: VPhoneLaunchpadMachineLibrary
    private let helper: VPhoneLaunchpadHelperClient

    init(bundles: VPhoneLaunchpadCoreBundle, machines: VPhoneLaunchpadMachineLibrary, helper: VPhoneLaunchpadHelperClient) {
        self.bundles = bundles
        self.machines = machines
        self.helper = helper
    }

    var orphans: [Lease] {
        leases.filter { $0.owner == "orphan" }
    }

    /// The libraries that hold machines. `vm leases --release-orphans`
    /// refuses a library with none, since every lease would look orphaned
    /// against it; one without machines has nothing to keep anyway.
    var libraryRoots: [String] {
        var roots: [String] = []
        for machine in machines.machines where !roots.contains(machine.libraryRoot) {
            roots.append(machine.libraryRoot)
        }
        return roots
    }

    private var libraryArguments: [String] {
        libraryRoots.flatMap { ["--library-root", $0] }
    }

    // MARK: - Listing

    func refresh() async {
        #if DEBUG
            if VPhoneLaunchpadPreview.isActive {
                return
            }
        #endif
        guard state != .checking, !isReleasing else {
            return
        }
        if !machines.hasListed {
            await machines.refresh()
        }
        guard let commandLine = bundles.commandLine() else {
            state = .unavailable(String(localized: "Needs a Core Bundle"))
            return
        }
        guard !libraryRoots.isEmpty else {
            leases = []
            state = .unavailable(String(localized: "No machines"))
            return
        }
        state = .checking
        do {
            let result = try await commandLine.run(["vm", "leases", "--json"] + libraryArguments, recordInHistory: false)
            guard result.succeeded, let data = result.jsonData else {
                state = .failed(result.lines.last ?? String(localized: "vm leases failed"))
                return
            }
            leases = try JSONDecoder().decode([Lease].self, from: data)
            state = .listed
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - Release

    /// Releases the orphans through the helper, which asks for an
    /// administrator, and lists again. Returns what was released.
    @discardableResult
    func release() async throws -> [Lease] {
        guard !isReleasing else {
            throw VPhoneLaunchpadError(String(localized: "Already releasing DHCP leases."))
        }
        guard let version = bundles.defaultVersion else {
            throw VPhoneLaunchpadError(String(localized: "Install a Core Bundle first."))
        }
        if !machines.hasListed {
            await machines.refresh()
        }
        let roots = libraryRoots
        guard !roots.isEmpty else {
            throw VPhoneLaunchpadError(
                String(localized: "No machines to compare against."),
                detail: String(localized: "With no machine listed, every guest's lease would look orphaned."),
            )
        }
        isReleasing = true
        defer { isReleasing = false }
        let output = try await helper.releaseOrphanedLeases(bundleVersion: version, libraryRoots: roots)
        let report = try JSONDecoder().decode([String: [Lease]].self, from: output)
        isReleasing = false
        await refresh()
        return report["released"] ?? []
    }

    /// For a button: errors land in `actionError`, a cancelled
    /// administrator prompt in nothing.
    func releaseFromUI() async {
        do {
            try await release()
        } catch is CancellationError {
        } catch let error as VPhoneLaunchpadError {
            actionError = error
        } catch {
            actionError = VPhoneLaunchpadError(String(localized: "Unable to Release DHCP Leases"), detail: error.localizedDescription)
        }
    }
}

#if DEBUG
    extension VPhoneLaunchpadLeases {
        func applyPreview(orphans: Int) {
            leases = [Lease(address: "192.168.64.22", mac: "02:8b:e3:17:a4:a0", name: "iPad", owner: "machine", machine: "research-01")]
                + (0 ..< orphans).map { index in
                    Lease(address: "192.168.64.\(100 + index)", mac: "0e:2f:62:cd:88:\(String(format: "%02x", index))", name: "iPhone", owner: "orphan", machine: nil)
                }
            state = .listed
        }
    }
#endif
