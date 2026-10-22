import Darwin

// vphone-launchpad-launcher: the process macOS holds responsible for every VM
// Launchpad starts. Launchpad starts it detached and responsible for itself;
// it starts `vphone-cli vm launch …` as an ordinary child and stays until that
// exits. As a tool in the app's Contents/MacOS it is attributed to the app,
// so privacy permissions the guest uses are asked for, and granted to, the
// Developer ID signed app once, instead of each ad hoc signed VPhone.bundle
// build. Because those grants are worth borrowing, it starts
// nothing but `vm launch` of a vphone-cli in the root-owned bundle store.
//
// Exit status: the child's, or the child's signal; 64 for a usage error, 77
// for a refusal, 71 when the child cannot be started.

// MARK: - Status

let usageStatus: Int32 = 64
let refusedStatus: Int32 = 77
let failedStatus: Int32 = 71

func fail(_ status: Int32, _ message: String) -> Never {
    let line = "vphone-launchpad-launcher: \(message)\n"
    _ = line.withCString { write(STDERR_FILENO, $0, strlen($0)) }
    exit(status)
}

// MARK: - Main

let arguments = Array(CommandLine.arguments.dropFirst())
guard let executable = arguments.first else {
    fail(usageStatus, "usage: vphone-launchpad-launcher <vphone-cli> vm launch <machine> [options]")
}

let path: String
do {
    path = try VPhoneLaunchpadLauncherPolicy.check(executable: executable, arguments: Array(arguments.dropFirst()))
} catch {
    fail(refusedStatus, "refused: \(error.message)")
}

let status: Int32
do {
    // argv[0] stays the path Launchpad named, as when it started vphone-cli
    // itself.
    status = try VPhoneLaunchpadLauncherProcess.run(path: path, argv: arguments)
} catch {
    fail(failedStatus, error.message)
}

VPhoneLaunchpadLauncherProcess.exit(withStatusOf: status)
