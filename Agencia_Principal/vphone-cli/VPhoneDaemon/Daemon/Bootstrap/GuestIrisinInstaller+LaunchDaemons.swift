import Foundation
import IcliKit

// MARK: - Bootstrap LaunchDaemons

extension GuestIrisinInstaller {
    /// The launchd hook does not import the bootstrap's daemons. As RootHide's
    /// `jbctl startup` does, vphoned loads `Library/LaunchDaemons` into the
    /// system domain once the root is repaired, under each plist's own path,
    /// so a package script's `launchctl bootout` of that path finds the job.
    /// No launchctl is needed: RootHide plists are rewritten here, and a job
    /// that is already loaded answers EEXIST, which IcliKit accepts.
    static func loadBootstrapDaemons(layout: String, root: String) {
        let directory = root + "/Library/LaunchDaemons"
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory) else { return }
        for name in names.sorted() where name.hasSuffix(".plist") {
            let plist = directory + "/" + name
            do {
                if layout == "roothide" {
                    try patchRootHideDaemon(at: plist, root: root)
                }
                _ = try loadServices([plist], load: true, override: false)
            } catch {
                NSLog("vphoned: could not load bootstrap daemon %@: %@", plist, String(describing: error))
            }
        }
    }

    /// `services.load` of a plist, or a directory of them, inside the RootHide
    /// root rewrites each before launchd reads it.
    static func prepareBootstrapDaemons(_ paths: [String]) throws {
        guard let installation = try completedBootstrap(), installation.layout == "roothide" else { return }
        let root = installation.root
        // standardizingPath drops the /private of /private/var, so compare
        // each path with the root spelled the same way.
        let prefix = (root as NSString).standardizingPath + "/"
        for path in paths.map({ ($0 as NSString).standardizingPath }) where path.hasPrefix(prefix) {
            if isDirectory(path) {
                for name in try FileManager.default.contentsOfDirectory(atPath: path).sorted()
                    where name.hasSuffix(".plist")
                {
                    try patchRootHideDaemon(at: path + "/" + name, root: root)
                }
            } else if path.hasSuffix(".plist") {
                try patchRootHideDaemon(at: path, root: root)
            }
        }
    }
}
