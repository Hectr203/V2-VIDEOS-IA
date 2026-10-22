import Darwin
import Foundation
import IcliKit

// MARK: - Package changes

extension GuestIrisinInstaller {
    private static let packageQueue = DispatchQueue(label: "vphoned.bootstrap.packages")
    private nonisolated(unsafe) static var packageWatch: DispatchSourceFileSystemObject?
    private nonisolated(unsafe) static var packageRefreshPending = false

    /// Irisin, apt and dpkg all rewrite Library/dpkg/status when they finish,
    /// so a changed directory means a package operation is done. RootHide
    /// relinks the new package's Mach-O directories then (see
    /// `repairRootHidePackages`), and both layouts register the bootstrap's
    /// apps as `uicache -a` would: a package's postinst runs uikittools'
    /// uicache, which cannot register apps on iOS 27. The apps are refreshed
    /// once when the watch starts too, for packages changed while vphoned was
    /// not running.
    static func watchBootstrapPackages(layout: String, root: String) {
        packageQueue.async {
            guard packageWatch == nil else { return }
            let directory = root + "/Library/dpkg"
            let descriptor = open(directory, O_EVTONLY | O_CLOEXEC)
            guard descriptor >= 0 else {
                NSLog("vphoned: cannot watch %@: %s", directory, strerror(errno))
                return
            }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor, eventMask: [.write, .delete, .rename], queue: packageQueue,
            )
            source.setEventHandler {
                guard let watch = packageWatch else { return }
                if !watch.data.isDisjoint(with: [.delete, .rename]) {
                    // The bootstrap was removed; a new install starts a new watch.
                    watch.cancel()
                    packageWatch = nil
                    return
                }
                guard !packageRefreshPending else { return }
                packageRefreshPending = true
                // Let the package manager finish writing before walking.
                packageQueue.asyncAfter(deadline: .now() + 1) {
                    packageRefreshPending = false
                    if layout == "roothide" {
                        repairRootHidePackages(root: root)
                    }
                    refreshBootstrapApps(root: root)
                }
            }
            source.setCancelHandler { close(descriptor) }
            packageWatch = source
            source.resume()
            refreshBootstrapApps(root: root)
        }
    }

    static func stopWatchingBootstrapPackages() {
        packageQueue.sync {
            packageWatch?.cancel()
            packageWatch = nil
        }
    }

    private static func refreshBootstrapApps(root: String) {
        do {
            let result = try refreshApps(directory: root + "/Applications")
            let changed = ["registered", "unregistered"].flatMap { result[$0] as? [String] ?? [] }
            if !changed.isEmpty {
                NSLog("vphoned: bootstrap app registrations: %@", changed.joined(separator: ", "))
            }
        } catch {
            NSLog("vphoned: could not refresh bootstrap app registrations: %@", String(describing: error))
        }
    }
}
