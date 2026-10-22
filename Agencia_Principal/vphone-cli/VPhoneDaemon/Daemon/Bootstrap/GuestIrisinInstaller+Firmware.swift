import Darwin
import Foundation

// MARK: - Firmware record

extension GuestIrisinInstaller {
    static func repairFirmwareRecord() throws -> [String: Any] {
        installLock.lock()
        defer { installLock.unlock() }
        guard let marker = try completedBootstrap(),
              try marker.root == bootstrapRoot(layout: marker.layout, detected: nil),
              isDirectory(marker.root)
        else { throw GuestAPIError.operationFailed("No valid completed vphoned bootstrap was found") }
        let firmware = try ensureFirmwareRecord(root: marker.root)
        return ["layout": marker.layout, "jbroot": marker.root,
                "firmware_version": firmware.version, "dpkg_database_updated": firmware.updated]
    }

    /// This vphone bootstrap has no firmware maintainer script. Write the
    /// virtual package into the same dpkg status file Irisin and its helper read.
    static func ensureFirmwareRecord(root: String) throws -> (version: String, updated: Bool) {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let version = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        let database = URL(fileURLWithPath: root, isDirectory: true)
            .appendingPathComponent("Library/dpkg", isDirectory: true)
        try FileManager.default.createDirectory(at: database, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o755])
        let statusURL = database.appendingPathComponent("status")
        var info = stat()
        let statusResult = lstat(statusURL.path, &info)
        if statusResult != 0, errno != ENOENT {
            throw GuestAPIError.operationFailed("Could not inspect dpkg status")
        }
        if statusResult == 0, info.st_mode & mode_t(S_IFMT) != mode_t(S_IFREG) {
            throw GuestAPIError.operationFailed("dpkg status is not a regular file")
        }
        let existing = statusResult == 0
            ? try String(contentsOf: statusURL, encoding: .utf8)
            : ""
        var paragraphs = existing.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let matches = paragraphs.indices.filter { index in
            paragraphs[index].split(separator: "\n").contains("Package: firmware")
        }
        guard matches.count <= 1 else {
            throw GuestAPIError.operationFailed("dpkg status contains duplicate firmware records")
        }
        if let index = matches.first {
            let lines = paragraphs[index].split(separator: "\n").map(String.init)
            let oldVersion = lines.first(where: { $0.hasPrefix("Version: ") })
                .map { String($0.dropFirst("Version: ".count)) } ?? ""
            guard lines.contains("Status: install ok installed") else {
                throw GuestAPIError.operationFailed("Existing firmware record is not installed")
            }
            if !lines.contains("Maintainer: vphoned") {
                return (oldVersion, false)
            }
            if oldVersion == version {
                return (version, false)
            }
            var updated = lines.map {
                $0.hasPrefix("Version: ") ? "Version: \(version)" : $0
            }
            if oldVersion.isEmpty {
                updated.append("Version: \(version)")
            }
            paragraphs[index] = updated.joined(separator: "\n")
        } else {
            paragraphs.append("""
            Package: firmware
            Essential: yes
            Status: install ok installed
            Priority: required
            Section: System
            Installed-Size: 0
            Maintainer: vphoned
            Architecture: all
            Version: \(version)
            Description: virtual package for this vphone iOS firmware
            """)
        }
        try (paragraphs.joined(separator: "\n\n") + "\n\n")
            .write(to: statusURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: statusURL.path)
        return (version, true)
    }
}
