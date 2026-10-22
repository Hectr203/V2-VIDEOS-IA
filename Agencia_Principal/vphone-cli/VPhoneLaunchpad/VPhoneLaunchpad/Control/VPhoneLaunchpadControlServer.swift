import Darwin
import Foundation

/// Serves `vphone-launchpad-cli` on `VPhoneLaunchpadControl.socketPath`.
///
/// Each connection gets its own thread: it reads the request line, runs the
/// handler on the main actor, streams the handler's output lines back, and
/// cancels the handler if the client hangs up first. Only peers running as
/// this user are served, and the socket itself is mode 0600.
final nonisolated class VPhoneLaunchpadControlServer: @unchecked Sendable {
    typealias Emit = @Sendable (String) -> Void
    typealias Handler = @MainActor @Sendable (VPhoneLaunchpadControlRequest, @escaping Emit) async -> VPhoneLaunchpadControlEvent

    private let handler: Handler
    private let lock = NSLock()
    private var listenFD: Int32 = -1

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    // MARK: - Listening

    /// Binds the socket and starts accepting. When another Launchpad already
    /// answers on the socket, this one leaves it alone.
    func start() throws {
        let path = VPhoneLaunchpadControl.socketPath
        try FileManager.default.createDirectory(at: VPhoneLaunchpadControl.directory, withIntermediateDirectories: true)
        var address = sockaddr_un()
        guard VPhoneLaunchpadControl.address(path, into: &address) else {
            throw VPhoneLaunchpadError("The control socket path is too long.", detail: path)
        }
        if Self.isServed(&address) {
            throw VPhoneLaunchpadError("Another Launchpad is already serving the command line tool.", detail: path)
        }
        unlink(path)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw Self.posixError("socket")
        }
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        // Owner only before anyone can connect: connect fails until listen.
        guard bound == 0, chmod(path, 0o600) == 0, listen(fd, 8) == 0 else {
            let error = Self.posixError("bind")
            close(fd)
            throw error
        }
        lock.withLock { listenFD = fd }
        Thread.detachNewThread { [self] in
            acceptLoop(fd)
        }
    }

    func stop() {
        let fd = lock.withLock {
            defer { listenFD = -1 }
            return listenFD
        }
        if fd >= 0 {
            close(fd)
            unlink(VPhoneLaunchpadControl.socketPath)
        }
    }

    private static func isServed(_ address: inout sockaddr_un) -> Bool {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            return false
        }
        defer { close(fd) }
        return withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) == 0
            }
        }
    }

    private static func posixError(_ call: String) -> VPhoneLaunchpadError {
        VPhoneLaunchpadError(
            "Unable to open the control socket.",
            detail: "\(call): \(String(cString: strerror(errno)))",
        )
    }

    private func acceptLoop(_ listenFD: Int32) {
        while true {
            let fd = accept(listenFD, nil, nil)
            if fd < 0 {
                if errno == EINTR || errno == ECONNABORTED {
                    continue
                }
                return
            }
            Thread.detachNewThread { [self] in
                serve(fd)
            }
        }
    }

    // MARK: - Connection

    private func serve(_ fd: Int32) {
        defer { close(fd) }
        var uid: uid_t = 0
        var gid: gid_t = 0
        guard getpeereid(fd, &uid, &gid) == 0, uid == getuid(),
              fcntl(fd, F_SETNOSIGPIPE, 1) != -1
        else {
            return
        }
        var timeout = timeval(tv_sec: 15, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        let writer = VPhoneLaunchpadControlWriter(fd: fd)
        // A reader thread may still emit after the command returns; the fd
        // number must not be written once it is closed and reused.
        defer { writer.close() }
        guard let line = Self.readLine(fd) else {
            writer.send(.failure("The request was empty, too long, or did not arrive in time."))
            return
        }
        guard let request = try? JSONDecoder().decode(VPhoneLaunchpadControlRequest.self, from: line) else {
            writer.send(.failure("The request is not valid JSON."))
            return
        }

        let finished = DispatchSemaphore(value: 0)
        let emit: Emit = { writer.send(.line($0)) }
        let task = Task { @MainActor [handler] in
            let event = await handler(request, emit)
            writer.send(event)
            finished.signal()
        }
        // The request is read in full, so anything readable now is the
        // client closing its end: the CLI was interrupted.
        while finished.wait(timeout: .now() + .milliseconds(250)) == .timedOut {
            var pollFD = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            guard poll(&pollFD, 1, 0) > 0 else {
                continue
            }
            var byte: UInt8 = 0
            if recv(fd, &byte, 1, MSG_DONTWAIT) <= 0 {
                task.cancel()
                finished.wait()
                return
            }
        }
    }

    /// One line, without its newline, of at most the request limit.
    private static func readLine(_ fd: Int32) -> Data? {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while data.count <= VPhoneLaunchpadControl.maximumRequestLength {
            let count = read(fd, &buffer, buffer.count)
            if count < 0, errno == EINTR {
                continue
            }
            guard count > 0 else {
                return nil
            }
            if let newline = buffer[0 ..< count].firstIndex(of: 0x0A) {
                data.append(contentsOf: buffer[0 ..< newline])
                return data
            }
            data.append(contentsOf: buffer[0 ..< count])
        }
        return nil
    }
}

/// Serializes events onto one connection. Output lines arrive from reader
/// threads while the final event comes from the main actor.
final nonisolated class VPhoneLaunchpadControlWriter: @unchecked Sendable {
    private let fd: Int32
    private let lock = NSLock()
    private var isClosed = false

    init(fd: Int32) {
        self.fd = fd
    }

    func send(_ event: VPhoneLaunchpadControlEvent) {
        lock.withLock {
            guard !isClosed else {
                return
            }
            if !VPhoneLaunchpadControl.write(event.encodedLine(), to: fd) {
                isClosed = true
            }
        }
    }

    func close() {
        lock.withLock { isClosed = true }
    }
}
