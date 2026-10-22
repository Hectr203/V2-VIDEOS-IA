import Darwin
import Foundation

@main
struct LauncherPolicyTests {
    typealias Policy = VPhoneLaunchpadLauncherPolicy

    static let launch = ["vm", "launch", "research-01"]

    static func main() throws {
        let fileManager = FileManager.default
        let temporary = try fileManager.url(
            for: .itemReplacementDirectory, in: .userDomainMask,
            appropriateFor: fileManager.temporaryDirectory, create: true,
        )
        defer { try? fileManager.removeItem(at: temporary) }
        // The store and its parents are owned by this user here; the status
        // lookup reports root as the owner unless a case says otherwise.
        let base = Policy.resolvedPath(temporary.path)!
        let store = base + "/Bundles"
        let macOS = store + "/2.4.0/VPhone.bundle/Contents/MacOS"
        let cli = macOS + "/vphone-cli"
        try make(cli)
        try make(macOS + "/vphone-vm")
        try make(store + "/2.4.0/vphone-cli")
        try make(store + "/a/b/VPhone.bundle/Contents/MacOS/vphone-cli")
        try make(base + "/outside/VPhone.bundle/Contents/MacOS/vphone-cli")
        try fileManager.createDirectory(
            atPath: store + "/dir/VPhone.bundle/Contents/MacOS/vphone-cli", withIntermediateDirectories: true,
        )
        try fileManager.createDirectory(
            atPath: store + "/2.5.0/VPhone.bundle/Contents/MacOS", withIntermediateDirectories: true,
        )
        try fileManager.createSymbolicLink(
            atPath: store + "/2.5.0/VPhone.bundle/Contents/MacOS/vphone-cli",
            withDestinationPath: base + "/outside/VPhone.bundle/Contents/MacOS/vphone-cli",
        )
        try fileManager.createSymbolicLink(atPath: base + "/link", withDestinationPath: cli)

        func check(
            _ executable: String,
            _ arguments: [String] = launch,
            root: String = store,
            overrides: [String: Policy.FileStatus] = [:],
        ) throws(VPhoneLaunchpadLauncherRefusal) -> String {
            try Policy.check(executable: executable, arguments: arguments, storeRoot: root, resolve: Policy.resolvedPath) {
                if let override = overrides[$0] {
                    return override
                }
                return Policy.fileStatus($0).map { Policy.FileStatus(owner: 0, mode: $0.mode) }
            }
        }

        func expectRefused(
            _ text: String,
            _ executable: String,
            _ arguments: [String] = launch,
            root: String = store,
            overrides: [String: Policy.FileStatus] = [:],
        ) {
            do {
                let path = try check(executable, arguments, root: root, overrides: overrides)
                fatalError("Expected a refusal (\(text)), accepted \(path)")
            } catch {
                precondition(error.message.contains(text), "Unexpected refusal: \(error.message)")
            }
        }

        // The vphone-cli of a store entry, named directly or through a link
        // from outside, runs from the store.
        let accepted: [(String, [String])] = [
            (cli, launch),
            (base + "/link", launch),
            (cli, ["vm", "launch", "research-01", "--dfu", "--library", "/tmp/x"]),
        ]
        for (path, arguments) in accepted {
            let resolved = try check(path, arguments)
            precondition(resolved == cli, "Accepted \(path) as \(resolved)")
        }

        // Only `vm launch <machine>`.
        for arguments in [[], ["vm"], ["vm", "launch"], ["vm", "stop", "research-01"],
                          ["launch", "vm", "research-01"], ["--headless", "vm", "launch"],
                          ["cfw", "install", "research-01"]]
        {
            expectRefused("only `vphone-cli vm launch <machine>`", cli, arguments)
        }

        // Only the vphone-cli of a bundle directly in the store.
        for path in [base + "/outside/VPhone.bundle/Contents/MacOS/vphone-cli", macOS + "/vphone-vm",
                     store + "/2.4.0/vphone-cli", store + "/a/b/VPhone.bundle/Contents/MacOS/vphone-cli",
                     store + "/2.5.0/VPhone.bundle/Contents/MacOS/vphone-cli", "/bin/sh"]
        {
            expectRefused("is not the vphone-cli of a bundle in \(store)", path)
        }
        expectRefused("is not a regular file", store + "/dir/VPhone.bundle/Contents/MacOS/vphone-cli")
        expectRefused("does not exist", macOS + "/missing")
        expectRefused("the bundle store", cli, root: base + "/none")

        // The file and every directory up to / are root's alone.
        let entries = [cli, macOS, store + "/2.4.0", store, base, "/"]
        for path in entries {
            let mode = Policy.fileStatus(path)!.mode
            let rejected = [
                Policy.FileStatus(owner: 501, mode: mode),
                Policy.FileStatus(owner: 0, mode: mode | S_IWGRP),
                Policy.FileStatus(owner: 0, mode: mode | S_IWOTH),
            ]
            for status in rejected {
                expectRefused("\(path) must be owned by root", cli, overrides: [path: status])
            }
        }
        expectRefused("\(macOS) is not a directory", cli, overrides: [macOS: Policy.FileStatus(owner: 0, mode: S_IFREG | 0o755)])
        print("Launcher policy tests passed: accepted paths, arguments, store layout, ownership and modes")

        if CommandLine.arguments.dropFirst().contains("--live") {
            // Checks only; nothing is started.
            let installed = (try? fileManager.contentsOfDirectory(atPath: VPhoneLaunchpadBundleStore.root.path)) ?? []
            for version in installed.sorted() {
                let path = VPhoneLaunchpadBundleStore.executable(version: version, named: "vphone-cli").path
                do {
                    try print("accepted \(Policy.check(executable: path, arguments: launch))")
                } catch {
                    print("refused \(version): \(error.message)")
                }
            }
        }
    }

    static func make(_ path: String) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: url)
    }
}
