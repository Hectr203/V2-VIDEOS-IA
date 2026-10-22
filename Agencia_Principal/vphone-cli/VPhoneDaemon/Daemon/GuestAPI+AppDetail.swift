import Foundation
import IcliKit
import IcliSystem
import VphonedNative

// MARK: - App Detail and System Control

extension GuestAPI {
    static func executeAppDetail(_ method: String, _ params: [String: Any]) throws -> [String: Any]? {
        switch method {
        case "apps.info":
            return try appInfo(string(params, "bundle_id"))
        case "apps.binary":
            return try appBinaryInfo(string(params, "bundle_id"))
        case "apps.data_dir":
            return try appDataDir(string(params, "bundle_id"))
        case "apps.url_schemes":
            return try appURLSchemes()
        case "apps.handlers":
            return try appHandlers(string(params, "url"))
        case "apps.registration":
            return try appRegistration(string(params, "path"))
        case "apps.register":
            return try registerApp(string(params, "path"))
        case "apps.unregister":
            let path = try string(params, "path")
            try requireForce(params, "unregister \(path)")
            return try unregisterApp(path, force: true)
        case "apps.unregister_dir":
            let directory = try string(params, "directory")
            try requireForce(params, "unregister every app in \(directory)")
            return try unregisterAppsInDirectory(directory, force: true)
        case "apps.network_policy":
            return try appNetworkPolicy(string(params, "bundle_id"), repair: bool(params, "repair"))
        case "system.uicache":
            return try refreshAppRegistrations(directory: optionalString(params, "directory"))
        case "system.system_apps":
            return try systemAppsVisibility(set: params["visible"] as? Bool)
        case "system.respring":
            try requireForce(params, "restart SpringBoard")
            return try respring()
        case "system.reboot":
            let userspace = bool(params, "userspace")
            try requireForce(params, userspace ? "restart userspace" : "reboot the guest")
            return try requestReboot(userspace: userspace, force: true)
        case "system.shutdown":
            try requireForce(params, "shut down the guest")
            return try requestShutdown()
        default:
            return nil
        }
    }
}

// MARK: - App Registrations

extension GuestAPI {
    /// `uicache -a`. Without a directory, IcliKit looks for the bootstrap from
    /// the running executable, and vphoned runs from the system volume, so it
    /// finds none and refreshes the system's /Applications, where every app is
    /// Apple's and is skipped. The bootstrap vphoned installed names the
    /// directory instead.
    static func refreshAppRegistrations(directory: String?) throws -> [String: Any] {
        guard let directory = try directory ?? GuestIrisinInstaller.completedBootstrap().map({ $0.root + "/Applications" })
        else {
            throw GuestAPIError.operationFailed("No bootstrap environment was found")
        }
        do {
            return try refreshApps(directory: directory)
        } catch let IcliError.commandFailed(output) {
            // The output names the bundles; the error itself gives only a status.
            let names = { (key: String) in
                (output[key] as? [String] ?? []).map { ($0 as NSString).lastPathComponent }.joined(separator: ", ")
            }
            var sentences: [String] = []
            if !names("failed").isEmpty {
                sentences.append("LaunchServices did not register or remove \(names("failed")).")
            }
            if !names("unverified").isEmpty {
                sentences.append("LaunchServices does not list \(names("unverified")) as expected after the refresh.")
            }
            throw GuestAPIError.operationFailed(sentences.joined(separator: " "))
        }
    }
}

// MARK: - Shutdown

extension GuestAPI {
    /// Asks launchd to shut the guest down. Success means launchd accepted the
    /// request; the guest then stops, which ends the virtual machine on the
    /// host, so the caller usually loses the connection before the reply.
    static func requestShutdown() throws -> [String: Any] {
        guard geteuid() == 0 else { throw GuestAPIError.operationFailed("shutdown requires root") }
        let status = vp_system_halt()
        guard status == 0 else {
            throw GuestAPIError.operationFailed("shutdown request rejected: \(String(cString: strerror(status)))")
        }
        return ["accepted": true, "completion": "the virtual machine stops"]
    }
}
