import Darwin

// MARK: - Failure

nonisolated struct VPhoneLaunchpadLauncherFailure: Error {
    let message: String
}

// MARK: - Child process

/// Runs one child for the launcher's whole life. The child is started without
/// disclaiming responsibility, so the process responsible for the launcher is
/// responsible for it too. The launcher only forwards stop signals and waits.
nonisolated enum VPhoneLaunchpadLauncherProcess {
    /// What Launchpad sends to stop a VM, plus what a terminal would.
    static let forwardedSignals: [Int32] = [SIGINT, SIGTERM, SIGHUP, SIGQUIT]

    /// Starts `path` with `argv` (argv[0] included), inheriting stdin, stdout,
    /// stderr, the working directory and the environment, and returns its wait
    /// status once it exits. The forwarded signals reach the child, not the
    /// launcher.
    static func run(path: String, argv: [String]) throws(VPhoneLaunchpadLauncherFailure) -> Int32 {
        let queue = kqueue()
        guard queue >= 0 else {
            throw VPhoneLaunchpadLauncherFailure(message: "kqueue failed: \(String(cString: strerror(errno)))")
        }
        defer { close(queue) }

        // A kqueue records a signal even while it is ignored, so ignoring them
        // here keeps the launcher alive and still sees each one. Signals that
        // arrive before the child exists are forwarded once it does. Those at
        // their default go back to it in the child; an inherited SIG_IGN is
        // inherited as before.
        var defaults = sigset_t()
        sigemptyset(&defaults)
        var changes: [kevent] = []
        for number in forwardedSignals {
            var previous = sigaction()
            sigaction(number, nil, &previous)
            if unsafeBitCast(previous.__sigaction_u, to: Int.self) == 0 {
                sigaddset(&defaults, number)
            }
            var ignore = sigaction()
            ignore.__sigaction_u.__sa_handler = SIG_IGN
            sigaction(number, &ignore, nil)
            changes.append(kevent(
                ident: UInt(number), filter: Int16(EVFILT_SIGNAL), flags: UInt16(EV_ADD),
                fflags: 0, data: 0, udata: nil,
            ))
        }
        guard kevent(queue, changes, Int32(changes.count), nil, 0, nil) == 0 else {
            throw VPhoneLaunchpadLauncherFailure(message: "kevent failed: \(String(cString: strerror(errno)))")
        }

        let pid = try spawn(path: path, argv: argv, defaults: &defaults)

        var childExit = kevent(
            ident: UInt(pid), filter: Int16(EVFILT_PROC), flags: UInt16(EV_ADD | EV_ONESHOT),
            fflags: UInt32(NOTE_EXIT), data: 0, udata: nil,
        )
        // ESRCH: the child already exited and only waits to be reaped.
        var running = kevent(queue, &childExit, 1, nil, 0, nil) == 0
        while running {
            var event = kevent()
            let count = kevent(queue, nil, 0, &event, 1, nil)
            if count < 0 {
                if errno == EINTR {
                    continue
                }
                break
            }
            if event.filter == Int16(EVFILT_SIGNAL) {
                // Until waitpid reaps it the PID cannot be reused, so this
                // only ever reaches our own child.
                kill(pid, Int32(event.ident))
            } else if event.filter == Int16(EVFILT_PROC) {
                running = false
            }
        }

        var status: Int32 = 0
        while waitpid(pid, &status, 0) == -1, errno == EINTR {}
        return status
    }

    /// Ends the launcher the way the child ended: with its exit code, or
    /// killed by the same signal, so whoever waits for the launcher sees the
    /// same status it would have seen for the child.
    static func exit(withStatusOf status: Int32) -> Never {
        let signal = status & 0x7F
        guard signal != 0 else {
            Darwin.exit((status >> 8) & 0xFF)
        }
        // The child already dumped core if it was going to.
        var limit = rlimit(rlim_cur: 0, rlim_max: 0)
        setrlimit(RLIMIT_CORE, &limit)
        var reset = sigaction()
        reset.__sigaction_u.__sa_handler = SIG_DFL
        sigaction(signal, &reset, nil)
        var unblock = sigset_t()
        sigemptyset(&unblock)
        sigaddset(&unblock, signal)
        sigprocmask(SIG_UNBLOCK, &unblock, nil)
        kill(getpid(), signal)
        Darwin.exit(128 + signal)
    }

    // MARK: - Spawn

    private static func spawn(
        path: String,
        argv: [String],
        defaults: inout sigset_t,
    ) throws(VPhoneLaunchpadLauncherFailure) -> pid_t {
        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        // No POSIX_SPAWN_SETSID and no disclaim: the child stays in the
        // launcher's session, and the launcher stays responsible for it.
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_CLOEXEC_DEFAULT))
        posix_spawnattr_setsigdefault(&attributes, &defaults)

        // Only the standard descriptors, which is all Launchpad gives the
        // launcher. The kqueue stays behind.
        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        for descriptor in [STDIN_FILENO, STDOUT_FILENO, STDERR_FILENO] where fcntl(descriptor, F_GETFD) != -1 {
            posix_spawn_file_actions_addinherit_np(&actions, descriptor)
        }

        let arguments = argv.map { strdup($0) } + [nil]
        defer { arguments.forEach { free($0) } }
        var pid: pid_t = 0
        let result = posix_spawn(&pid, path, &actions, &attributes, arguments, environ)
        guard result == 0 else {
            throw VPhoneLaunchpadLauncherFailure(
                message: "unable to start \(path): \(String(cString: strerror(result)))",
            )
        }
        return pid
    }
}
