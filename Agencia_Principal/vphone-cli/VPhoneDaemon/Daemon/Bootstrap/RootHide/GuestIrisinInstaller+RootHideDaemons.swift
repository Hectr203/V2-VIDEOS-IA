import Foundation

// MARK: - RootHide LaunchDaemon plists

extension GuestIrisinInstaller {
    /// Rewrites a bootstrap LaunchDaemon plist in place the way RootHide's
    /// launchctl does (`plistpatch.m`), because launchd runs outside vroot and
    /// needs kernel paths. RootHide renames its root at every jailbreak, so its
    /// launchctl takes the old root off a `__Patched` plist before putting the
    /// new one on. vphone's root never changes, so a `__Patched` plist is
    /// already right, and that launchctl turns one written here back into the
    /// same file. A plist whose program is under `/rootfs/` is a system job and
    /// is left alone. Returns whether the file changed.
    @discardableResult
    static func patchRootHideDaemon(at path: String, root: String) throws -> Bool {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        guard var plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw GuestAPIError.operationFailed("LaunchDaemon plist is invalid: \(path)")
        }
        if plist["__Patched"] as? Bool == true {
            return false
        }
        func physical(_ value: String) -> String {
            guard value.hasPrefix("/") else { return value }
            if value.hasPrefix("/rootfs/") {
                return String(value.dropFirst("/rootfs".count))
            }
            let aliased = "/var" + root.dropFirst("/private/var".count)
            if value.hasPrefix(root + "/") || value.hasPrefix(aliased + "/") {
                return value
            }
            return root + value
        }
        func physicalList(_ value: Any?) -> [Any]? {
            (value as? [Any])?.map { ($0 as? String).map(physical) ?? $0 }
        }

        var arguments = plist["ProgramArguments"] as? [Any]
        let program = plist["Program"] as? String ?? arguments?.first as? String
        if program?.hasPrefix("/rootfs/") == true {
            return false
        }
        // Only the executable moves, as RootHide's launchctl does: the other
        // arguments are read by the program itself, inside vroot.
        if let value = plist["Program"] as? String {
            plist["Program"] = physical(value)
        } else if let first = arguments?.first as? String {
            arguments![0] = physical(first)
            plist["ProgramArguments"] = arguments
        }
        for key in ["RootDirectory", "WorkingDirectory", "StandardInPath", "StandardOutPath", "StandardErrorPath"] {
            if let value = plist[key] as? String {
                plist[key] = physical(value)
            }
        }
        for key in ["WatchPaths", "QueueDirectories"] {
            if let value = physicalList(plist[key]) {
                plist[key] = value
            }
        }
        if var environment = plist["EnvironmentVariables"] as? [String: Any] {
            for key in ["CFFIXED_USER_HOME", "HOME", "TMPDIR"] {
                if let value = environment[key] as? String {
                    environment[key] = physical(value)
                }
            }
            plist["EnvironmentVariables"] = environment
        }
        if var keepAlive = plist["KeepAlive"] as? [String: Any],
           let states = keepAlive["PathState"] as? [String: Any]
        {
            keepAlive["PathState"] = Dictionary(states.map { (physical($0.key), $0.value) }) { first, _ in first }
            plist["KeepAlive"] = keepAlive
        }
        if let sockets = plist["Sockets"] as? [String: Any] {
            plist["Sockets"] = sockets.mapValues { value -> Any in
                guard var socket = value as? [String: Any], let name = socket["SockPathName"] as? String else {
                    return value
                }
                socket["SockPathName"] = physical(name)
                return socket
            }
        }
        if var events = plist["LaunchEvents"] as? [String: Any],
           let matching = events["com.apple.fsevents.matching"] as? [String: Any]
        {
            events["com.apple.fsevents.matching"] = matching.mapValues { value -> Any in
                guard var event = value as? [String: Any], let path = event["Path"] as? String else { return value }
                event["Path"] = physical(path)
                return event
            }
            plist["LaunchEvents"] = events
        }
        plist["__Patched"] = true
        let updated = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try updated.write(to: url, options: .atomic)
        return true
    }
}
