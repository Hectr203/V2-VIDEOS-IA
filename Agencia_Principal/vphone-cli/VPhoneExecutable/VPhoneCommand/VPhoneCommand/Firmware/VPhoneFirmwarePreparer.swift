import Darwin
import FirmwarePatcher
import Foundation
import VPhoneArchiveKit
import VPhoneCoreKit

/// Builds one restore tree from two IPSWs without a shell or a second full
/// copy of either source archive. All extraction and merging happens in one
/// disposable directory inside the VM; only a complete tree is moved into
/// place for the patch/restore steps to see.
enum VPhoneFirmwarePreparer {
    enum Error: Swift.Error, LocalizedError {
        case existingRestore(URL)
        case missingComponent(URL)
        case sourceNameMismatch(URL, version: String, build: String)
        case deviceNotInSource(String, available: [String])

        var errorDescription: String? {
            switch self {
            case let .existingRestore(path):
                "A restore tree already exists at \(path.path). Remove it, then prepare the firmware again."
            case let .missingComponent(path):
                "A firmware component is missing: \(path.path). Check that the IPSW is complete, then prepare the firmware again."
            case let .sourceNameMismatch(path, version, build):
                "The IPSW file name does not match its contents (\(version)/\(build)): \(path.path). Use the original file name or download the IPSW again."
            case let .deviceNotInSource(productType, available):
                "The IPSW does not contain \(productType); it covers \(available.joined(separator: ", ")). Choose one of those with --device, or use that model's IPSW."
            }
        }
    }

    static func prepare(
        iPhoneSource: String,
        cloudOSSource: String,
        gpuDriverBundle: URL? = nil,
        ipswCacheDirectory: URL = VPhoneResources.ipswCacheDirectory(),
        downloadConnections: Int = VPhoneIPSWCache.defaultDownloadConnections,
        device productType: String? = nil,
        bundle: VPhoneBundle,
        resources: VPhoneResources,
    ) throws {
        let fm = FileManager.default
        let existing = try fm.contentsOfDirectory(
            at: bundle.url,
            includingPropertiesForKeys: [.isDirectoryKey],
        )
        for candidate in existing where candidate.lastPathComponent.contains("Restore") {
            if try candidate.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true {
                throw Error.existingRestore(candidate)
            }
        }

        // No restore tree, so any kept boot-chain originals describe firmware that
        // is no longer here. Leaving them would be worse than having none: the
        // component paths under a same-named restore tree — and `AVPBooter*.bin`
        // in the bundle root, whose name does not carry a version at all — would
        // match, and the next `fw patch` would patch last firmware's bytes and
        // save them over this one's. See FirmwarePipelineOriginals.swift.
        let staleOriginals = bundle.url
            .appendingPathComponent(VPhoneBundleOperations.firmwareOriginalsDirectoryName)
        if fm.fileExists(atPath: staleOriginals.path) {
            print("[*] Removing boot-chain originals kept for the previous firmware...")
            try fm.removeItem(at: staleOriginals)
        }

        let (phone, cloud, device) = try resolveSources(
            iPhoneSource: iPhoneSource,
            cloudOSSource: cloudOSSource,
            ipswCacheDirectory: ipswCacheDirectory,
            device: productType,
            downloadConnections: downloadConnections,
        )

        let name = device.restoreTreeName(version: phone.version, build: phone.build)
        let destination = bundle.url.appendingPathComponent(name)
        let staging = bundle.url.appendingPathComponent(".firmware-prepare-\(UUID().uuidString)")
        let phoneTree = staging.appendingPathComponent(name)
        let cloudTree = staging.appendingPathComponent("cloudOS")
        try fm.createDirectory(at: staging, withIntermediateDirectories: false)
        defer {
            let entries = (try? fm.contentsOfDirectory(atPath: staging.path)) ?? []
            if entries.contains(where: { $0.hasPrefix(".pcc-system-") || $0.hasPrefix(".pcc-restoration-") }) {
                fputs("warning: PCC mount may still be active; left staging at \(staging.path)\n", stderr)
            } else {
                try? fm.removeItem(at: staging)
            }
        }
        try fm.createDirectory(at: phoneTree, withIntermediateDirectories: false)
        try fm.createDirectory(at: cloudTree, withIntermediateDirectories: false)

        print("[*] Extracting \(device.productType) IPSW...")
        try VPhoneArchiveExtractor.extract(phone.file, into: phoneTree, options: .intoHostDirectory)
        print("[*] Extracting cloudOS IPSW...")
        try VPhoneArchiveExtractor.extract(cloud.file, into: cloudTree, options: .intoHostDirectory)

        try makeUserWritable(phoneTree)
        try mergeCloudOS(from: cloudTree, into: phoneTree)
        let originalManifest = phoneTree.appendingPathComponent("BuildManifest.plist")
        try clone(originalManifest, to: phoneTree.appendingPathComponent("iPhone-BuildManifest.plist"))
        try FirmwareManifest.generate(iPhoneDir: phoneTree, cloudOSDir: cloudTree, device: device, verbose: true)
        let cachedDriver = cachedGPUDriver(for: cloud)
        if let gpuDriverBundle {
            print("[*] Staging GPU driver from local bundle...")
            try VPhonePCCGPUDriver.stage(
                from: gpuDriverBundle,
                into: phoneTree,
                expectedPlatformVersion: cloud.version,
            )
        } else if (try? VPhonePCCGPUDriver.stage(
            from: cachedDriver,
            into: phoneTree,
            expectedPlatformVersion: cloud.version,
        )) != nil {
            print("[+] GPU driver reused from cloudOS \(cloud.version) (\(cloud.build)) cache")
        } else {
            print("[*] Restoring cloudOS in a temporary vphone VM to extract its GPU driver...")
            try VPhonePCCGPURecovery.stage(
                cloudOSDirectory: cloudTree,
                into: phoneTree,
                expectedPlatformVersion: cloud.version,
            )
            // Every later machine on this cloudOS build skips the restore.
            do {
                try storeGPUDriver(VPhonePCCGPUDriver.stagedBundle(in: phoneTree), at: cachedDriver)
            } catch {
                fputs("warning: could not cache the GPU driver at \(cachedDriver.path): \(error.localizedDescription)\n", stderr)
            }
        }

        let source = resources.gpuCompilerPlugin
        guard fm.fileExists(atPath: source.path) else { throw Error.missingComponent(source) }
        print("[*] Merging bundled GPU compiler plugin...")
        let pluginName = "libAppleParavirtCompilerPluginIOGPUFamily.dylib"
        let destinationPlugin = VPhonePCCGPUDriver.stagedBundle(in: phoneTree).appendingPathComponent(pluginName)
        if fm.fileExists(atPath: destinationPlugin.path) {
            try fm.removeItem(at: destinationPlugin)
        }
        try fm.copyItem(at: source, to: destinationPlugin)
        try fm.setAttributes([.posixPermissions: NSNumber(value: 0o755)], ofItemAtPath: destinationPlugin.path)

        // The destination did not exist at entry and the staging directory is
        // on the same volume. One rename exposes the complete restore tree.
        guard !fm.fileExists(atPath: destination.path) else { throw Error.existingRestore(destination) }
        try fm.moveItem(at: phoneTree, to: destination)
        print("[+] Restore tree ready: \(destination.path)")
        try recordGuestDevice(device, in: bundle)
    }

    /// Finds both IPSWs, downloading a remote one into the shared cache, and
    /// the guest device the iPhone IPSW gives, without extracting anything.
    /// `vm create` calls it before `prepare` to learn the template key; the
    /// second call finds both in place.
    static func resolveSources(
        iPhoneSource: String,
        cloudOSSource: String,
        ipswCacheDirectory: URL = VPhoneResources.ipswCacheDirectory(),
        device productType: String? = nil,
        downloadConnections: Int = VPhoneIPSWCache.defaultDownloadConnections,
    ) throws -> (phone: VPhoneIPSWCache.Archive, cloud: VPhoneIPSWCache.Archive, device: VPhoneGuestDevice) {
        // Remote IPSWs go to one cache shared by every machine; keeping them
        // inside the machine downloaded both again for each new one (#513).
        // Local IPSWs are read in place and are never copied into the cache.
        print("[*] Resolving iPhone IPSW...")
        let phone = try resolve(
            iPhoneSource, in: ipswCacheDirectory, connections: downloadConnections, label: "downloading iPhone IPSW",
        )
        print("[*] Resolving cloudOS IPSW...")
        let cloud = try resolve(
            cloudOSSource, in: ipswCacheDirectory, connections: downloadConnections, label: "downloading cloudOS IPSW",
        )
        try VPhoneIPSWCache.checkPair(iPhone: phone, cloudOS: cloud)
        let device = VPhoneIPSWCache.guestDevice(for: phone, preferring: productType) ?? .default
        if let productType, VPhoneGuestDevice.named(productType) != device {
            throw Error.deviceNotInSource(productType, available: phone.productTypes)
        }
        try checkIPhoneName(iPhoneSource, archive: phone, device: device)
        print("[+] \(device.productType) \(phone.version) (\(phone.build)); cloudOS \(cloud.version) (\(cloud.build))")
        return (phone, cloud, device)
    }

    /// Resolves one source, with a progress bar while it downloads. Launchpad
    /// reads the bar as `progress` lines and shows the percentage on its
    /// firmware step (#590).
    private static func resolve(
        _ source: String,
        in cacheDirectory: URL,
        connections: Int,
        label: String,
    ) throws -> VPhoneIPSWCache.Archive {
        let bar = VPhoneProgressBar(label: label)
        let archive = try vphoneRunBlocking {
            try await VPhoneIPSWCache.resolve(source, in: cacheDirectory, connections: connections) { done, total in
                bar.update(done: done, total: total)
            }
        }
        bar.finish()
        return archive
    }

    /// Records which device's OS the VM runs, and gives it that device's
    /// display. `fw patch` reads the device back from the restore tree; the
    /// manifest is what the VM window and the guest's screen size follow.
    static func recordGuestDevice(_ device: VPhoneGuestDevice, in bundle: VPhoneBundle) throws {
        let configURL = bundle.url.appendingPathComponent("config.plist")
        guard FileManager.default.fileExists(atPath: configURL.path) else { return }
        let manifest = try VPhoneVirtualMachineManifest.load(from: configURL)
        let updated = manifest.updating(guestDevice: device)
        guard updated.guestProductType != manifest.guestProductType
            || updated.screenConfig != manifest.screenConfig
        else { return }
        try updated.write(to: configURL)
        let screen = updated.screenConfig
        print("[+] Guest device: \(device.productName) (\(device.productType)), display \(screen.width)x\(screen.height) @ \(screen.pixelsPerInch) ppi")
    }

    // MARK: - GPU driver cache

    /// Where the driver recovered from this cloudOS build is kept. The bundle
    /// is cached as the System volume has it, before the compiler plugin merge.
    static func cachedGPUDriver(
        for cloud: VPhoneIPSWCache.Archive,
        in cacheDirectory: URL = VPhoneResources.gpuDriverCacheDirectory(),
    ) -> URL {
        cacheDirectory
            .appendingPathComponent("\(cloud.version)_\(cloud.build)", isDirectory: true)
            .appendingPathComponent(VPhonePCCGPUDriver.name, isDirectory: true)
    }

    /// Copies into a private directory, then renames it into place, so a
    /// concurrent prepare never sees half a bundle. If another prepare stores
    /// the same build in between, its copy is kept.
    static func storeGPUDriver(_ bundle: URL, at destination: URL) throws {
        let fm = FileManager.default
        let buildDirectory = destination.deletingLastPathComponent()
        let cacheDirectory = buildDirectory.deletingLastPathComponent()
        try fm.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try VPhoneHostFilePermissions.makeDirectoryAccessible(at: cacheDirectory)
        let pending = cacheDirectory.appendingPathComponent(".\(UUID().uuidString).partial", isDirectory: true)
        defer { try? fm.removeItem(at: pending) }
        try fm.createDirectory(at: pending, withIntermediateDirectories: false)
        try fm.copyItem(at: bundle, to: pending.appendingPathComponent(destination.lastPathComponent))
        try VPhoneHostFilePermissions.makeAccessible(at: pending)
        // This runs only when the cached copy did not stage, so whatever is
        // there is incomplete or damaged and would block the rename for good.
        if fm.fileExists(atPath: buildDirectory.path) {
            try fm.removeItem(at: buildDirectory)
        }
        do {
            try fm.moveItem(at: pending, to: buildDirectory)
        } catch {
            if fm.fileExists(atPath: destination.path) {
                return
            }
            throw error
        }
    }

    private static func checkIPhoneName(
        _ source: String,
        archive: VPhoneIPSWCache.Archive,
        device: VPhoneGuestDevice,
    ) throws {
        let basename = URL(string: source)?.lastPathComponent
            ?? URL(fileURLWithPath: source).lastPathComponent
        // An iPad IPSW names every model it covers: `iPad16,1,iPad16,2_…`.
        let product = NSRegularExpression.escapedPattern(for: device.productType)
        let pattern = "^(?:[^_/]*,)?" + product + "(?:,[^_/]*)?_([^_]+)_([^_]+)_Restore\\.ipsw$"
        guard let range = basename.range(of: pattern, options: .regularExpression) else { return }
        let components = basename[range].split(separator: "_")
        guard components.count == 4 else { return }
        if String(components[1]) != archive.version || String(components[2]) != archive.build {
            throw Error.sourceNameMismatch(archive.file, version: archive.version, build: archive.build)
        }
    }

    private static func mergeCloudOS(from cloud: URL, into phone: URL) throws {
        let fm = FileManager.default
        try copyMatching(from: cloud, into: phone) { $0.hasPrefix("kernelcache.") }
        for subdirectory in ["agx", "all_flash", "ane", "dfu", "pmp"] {
            let source = cloud.appending(path: "Firmware/\(subdirectory)")
            let destination = phone.appending(path: "Firmware/\(subdirectory)")
            guard fm.fileExists(atPath: source.path) else { throw Error.missingComponent(source) }
            try fm.createDirectory(at: destination, withIntermediateDirectories: true)
            try copyMatching(from: source, into: destination) { _ in true }
        }
        let cloudFirmware = cloud.appendingPathComponent("Firmware")
        let phoneFirmware = phone.appendingPathComponent("Firmware")
        try copyMatching(from: cloudFirmware, into: phoneFirmware) { $0.hasSuffix(".im4p") }
        try copyMatching(from: cloud, into: phone, overwrite: false) { $0.hasSuffix(".dmg") }
        try copyMatching(from: cloudFirmware, into: phoneFirmware, overwrite: false) {
            $0.hasSuffix(".dmg.trustcache")
        }
    }

    private static func copyMatching(
        from source: URL,
        into destination: URL,
        overwrite: Bool = true,
        where predicate: (String) -> Bool,
    ) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path) else { throw Error.missingComponent(source) }
        let names = try fm.contentsOfDirectory(atPath: source.path).filter(predicate)
        for name in names {
            let to = destination.appendingPathComponent(name)
            if !overwrite, fm.fileExists(atPath: to.path) {
                continue
            }
            try clone(source.appendingPathComponent(name), to: to)
        }
    }

    private static func clone(_ source: URL, to destination: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path) else { throw Error.missingComponent(source) }
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        if clonefile(source.path, destination.path, 0) == 0 {
            return
        }
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: source, to: destination)
    }

    private static func makeUserWritable(_ directory: URL) throws {
        let fm = FileManager.default
        guard let entries = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isSymbolicLinkKey],
        ) else { return }
        for case let file as URL in entries {
            let values = try file.resourceValues(forKeys: [.isSymbolicLinkKey])
            if values.isSymbolicLink == true {
                continue
            }
            let attributes = try fm.attributesOfItem(atPath: file.path)
            let mode = (attributes[.posixPermissions] as? NSNumber)?.uint16Value ?? 0o644
            try fm.setAttributes(
                [.posixPermissions: NSNumber(value: mode | 0o200)],
                ofItemAtPath: file.path,
            )
        }
    }
}
