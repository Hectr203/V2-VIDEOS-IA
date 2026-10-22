import Darwin
import Foundation

/// Drives the launcher's spawn, forward and wait core with /bin/sh. The
/// launcher itself only starts a root-owned vphone-cli, so this binary runs
/// the same core as a relay of its own (`--relay <program> <arguments…>`) and
/// checks from outside what Launchpad would see.
@main
struct LauncherProcessTests {
    static func main() throws {
        let arguments = CommandLine.arguments
        if arguments.count > 2, arguments[1] == "--relay" {
            let argv = Array(arguments.dropFirst(2))
            do {
                let status = try VPhoneLaunchpadLauncherProcess.run(path: argv[0], argv: argv)
                VPhoneLaunchpadLauncherProcess.exit(withStatusOf: status)
            } catch {
                fatalError(error.message)
            }
        }

        // Exit codes come back unchanged.
        for code in [0, 3, 255] as [Int32] {
            let relay = try Relay("exit \(code)")
            relay.expectExit(code)
        }

        // A child killed by a signal kills the launcher with the same one.
        for signal in [SIGTERM, SIGKILL, SIGUSR1] {
            let relay = try Relay("kill -\(signal) $$")
            relay.expectSignal(signal)
        }

        // stdin, stdout, the working directory and the environment reach the
        // child.
        let directory = try FileManager.default.url(
            for: .itemReplacementDirectory, in: .userDomainMask,
            appropriateFor: FileManager.default.temporaryDirectory, create: true,
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let relay = try Relay(
            "read line; printf '%s %s %s\\n' \"$line\" \"$VPHONE_LAUNCHER_TEST\" \"$(/bin/pwd -P)\"",
            directory: directory,
            environment: ["VPHONE_LAUNCHER_TEST": "inherited"],
            input: "hello\n",
        )
        relay.expectExit(0)
        let expected = "hello inherited \(realPath(directory.path))"
        precondition(relay.output.hasPrefix(expected), "Unexpected output: \(relay.output)")

        // Each stop signal is forwarded: the child's trap decides the exit
        // code, and the launcher survives to report it.
        let traps = VPhoneLaunchpadLauncherProcess.forwardedSignals.enumerated()
            .map { "trap 'exit \(40 + $0.offset)' \($0.element)" }
            .joined(separator: "; ")
        for (offset, signal) in VPhoneLaunchpadLauncherProcess.forwardedSignals.enumerated() {
            let relay = try Relay("\(traps); echo ready; while :; do /bin/sleep 0.05; done")
            relay.waitForReady()
            kill(relay.process.processIdentifier, signal)
            relay.expectExit(Int32(40 + offset))
        }

        // The launcher ignores the forwarded signals itself, but a child
        // without a trap gets them at their default and dies of them.
        for signal in VPhoneLaunchpadLauncherProcess.forwardedSignals {
            let relay = try Relay("echo ready; while :; do /bin/sleep 0.05; done")
            relay.waitForReady()
            kill(relay.process.processIdentifier, signal)
            relay.expectSignal(signal)
        }

        print("Launcher process tests passed: exit codes, signal deaths, inherited stdio/cwd/environment, forwarded signals")
    }
}

// MARK: - Relay

final class Relay {
    let process = Process()
    private let outputPipe = Pipe()
    private var collected = Data()
    private let script: String

    init(_ script: String, directory: URL? = nil, environment: [String: String] = [:], input: String? = nil) throws {
        self.script = script
        process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        process.arguments = ["--relay", "/bin/sh", "-c", script]
        if let directory {
            process.currentDirectoryURL = directory
        }
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { $1 }
        let stdin = Pipe()
        process.standardInput = stdin
        process.standardOutput = outputPipe
        try process.run()
        if let input {
            stdin.fileHandleForWriting.write(Data(input.utf8))
        }
        try stdin.fileHandleForWriting.close()
    }

    var output: String {
        String(decoding: collected, as: UTF8.self)
    }

    func waitForReady() {
        while !output.contains("ready\n") {
            let chunk = outputPipe.fileHandleForReading.availableData
            precondition(!chunk.isEmpty, "\(script): exited before it was ready")
            collected.append(chunk)
        }
    }

    private func finish() {
        collected.append(outputPipe.fileHandleForReading.readDataToEndOfFile())
        process.waitUntilExit()
    }

    func expectExit(_ code: Int32) {
        finish()
        precondition(
            process.terminationReason == .exit && process.terminationStatus == code,
            "\(script): expected exit \(code), got \(process.terminationReason.rawValue)/\(process.terminationStatus)",
        )
    }

    func expectSignal(_ signal: Int32) {
        finish()
        precondition(
            process.terminationReason == .uncaughtSignal && process.terminationStatus == signal,
            "\(script): expected signal \(signal), got \(process.terminationReason.rawValue)/\(process.terminationStatus)",
        )
    }
}

/// /var is a symlink to /private/var; the child reports the physical path.
func realPath(_ path: String) -> String {
    guard let resolved = realpath(path, nil) else {
        return path
    }
    defer { free(resolved) }
    return String(cString: resolved)
}
