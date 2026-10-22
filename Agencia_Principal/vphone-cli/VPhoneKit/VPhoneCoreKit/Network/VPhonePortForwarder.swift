import Foundation
import os

// MARK: - Port forwarding

/// Host ports carried into the guest, for the forwards in a VM's manifest.
///
/// Listening happens here, in `vphone-vm`, as an ordinary unprivileged
/// process: no pf rules, no root, and nothing left behind when the VM stops.
/// Where an accepted client goes depends on the network:
///
/// - `nat`: the Mac reaches the guest by address over the vmnet network, so a
///   TCP client is relayed over a second socket to the guest, and a UDP client
///   gets a connected socket of its own.
/// - `tunnel`: no host route reaches the guest, so the client is handed to the
///   userspace network, which presents it to the guest as a peer at the gateway.
///
/// Threading: every field is touched only on `queue`. That is the invariant
/// behind `@unchecked Sendable`.
public final class VPhonePortForwarder: @unchecked Sendable {
    public typealias PortForward = VPhoneVirtualMachineManifest.NetworkConfig.PortForward

    public enum Destination: Sendable {
        /// The guest's address on a network the host is part of. Nil until it
        /// is known; `updateGuestAddress` fills it in for a DHCP guest.
        case direct(VPhoneIPv4Address?)
        case tunnel(VPhoneUserspaceNetwork)
    }

    /// A UDP client of a forwarded port in `direct` mode.
    private final class UDPSession {
        let socket: Int32
        let source: DispatchSourceRead
        var lastActivity = Date()

        init(socket: Int32, source: DispatchSourceRead) {
            self.socket = socket
            self.source = source
        }
    }

    private static let log = Logger(subsystem: "com.vphone.network", category: "forward")
    private static let udpIdleTimeout: TimeInterval = 60
    private static let datagramCapacity = 65535

    public let forwards: [PortForward]
    private let destination: Destination
    private let queue = DispatchQueue(label: "com.vphone.port-forward")
    private var guestAddress: VPhoneIPv4Address?
    private var listeners: [DispatchSourceRead] = []
    private var relays: [ObjectIdentifier: VPhoneStreamRelay] = [:]
    private var udpSessions: [String: UDPSession] = [:]
    private var isStopped = false

    public init(forwards: [PortForward], destination: Destination) {
        self.forwards = forwards
        self.destination = destination
        if case let .direct(address) = destination {
            guestAddress = address
        }
    }

    /// Open every listener. Returns a line for each forward that could not be
    /// opened (usually a port something else holds); the rest still work.
    @discardableResult
    public func start() -> [String] {
        queue.sync {
            var failures: [String] = []
            for forward in forwards {
                do {
                    try listen(forward)
                } catch {
                    failures.append("\(forward): \(error)")
                }
            }
            return failures
        }
    }

    public func stop() {
        queue.sync {
            guard !isStopped else { return }
            isStopped = true
            listeners.forEach { $0.cancel() }
            listeners.removeAll()
            relays.values.forEach { $0.close() }
            relays.removeAll()
            udpSessions.values.forEach { $0.source.cancel() }
            udpSessions.removeAll()
        }
    }

    /// Where `direct` forwards go from now on. Connections already open keep
    /// the address they were made to.
    public func updateGuestAddress(_ address: VPhoneIPv4Address?) {
        queue.async { [self] in
            guard case .direct = destination, address != guestAddress else { return }
            guestAddress = address
            Self.log.info("forwarding to \(address?.description ?? "nothing", privacy: .public)")
        }
    }

    // MARK: - Listening

    private struct SocketError: Error, CustomStringConvertible {
        let call: String
        let code: Int32

        var description: String {
            "\(call): \(String(cString: strerror(code)))"
        }
    }

    private func listen(_ forward: PortForward) throws {
        guard let address = VPhoneIPv4Address(dotted: forward.listenAddress) else {
            throw SocketError(call: "address", code: EINVAL)
        }
        let tcp = forward.transport == .tcp
        let descriptor = socket(AF_INET, tcp ? SOCK_STREAM : SOCK_DGRAM, 0)
        guard descriptor >= 0 else { throw SocketError(call: "socket", code: errno) }
        var one: Int32 = 1
        _ = setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &one, socklen_t(MemoryLayout<Int32>.size))
        _ = fcntl(descriptor, F_SETNOSIGPIPE, 1)

        var socketAddress = Self.socketAddress(address, port: UInt16(forward.hostPort))
        let bound = withUnsafePointer(to: &socketAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else {
            let code = errno
            Darwin.close(descriptor)
            throw SocketError(call: "bind \(forward.listenAddress):\(forward.hostPort)", code: code)
        }
        if tcp, Darwin.listen(descriptor, 64) != 0 {
            let code = errno
            Darwin.close(descriptor)
            throw SocketError(call: "listen", code: code)
        }
        _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL, 0) | O_NONBLOCK)

        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
        let guestPort = UInt16(forward.guestPort)
        source.setEventHandler { [weak self] in
            if tcp {
                self?.acceptClients(listener: descriptor, guestPort: guestPort)
            } else {
                self?.receiveDatagrams(listener: descriptor, guestPort: guestPort)
            }
        }
        source.setCancelHandler { Darwin.close(descriptor) }
        source.resume()
        listeners.append(source)
        Self.log.info("forwarding \(forward.description, privacy: .public)")
    }

    static func socketAddress(_ address: VPhoneIPv4Address, port: UInt16) -> sockaddr_in {
        var socketAddress = sockaddr_in()
        socketAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        socketAddress.sin_family = sa_family_t(AF_INET)
        socketAddress.sin_port = port.bigEndian
        socketAddress.sin_addr = in_addr(s_addr: address.raw.bigEndian)
        return socketAddress
    }

    // MARK: - TCP

    private func acceptClients(listener: Int32, guestPort: UInt16) {
        while !isStopped {
            let client = accept(listener, nil, nil)
            guard client >= 0 else { return } // EAGAIN: none left
            _ = fcntl(client, F_SETNOSIGPIPE, 1)
            switch destination {
            case let .tunnel(network):
                network.acceptInbound(tcp: client, guestPort: guestPort)
            case .direct:
                relay(client, toGuestPort: guestPort)
            }
        }
    }

    private func relay(_ client: Int32, toGuestPort guestPort: UInt16) {
        guard let guestAddress else {
            Self.log.error("dropping a client of guest port \(guestPort, privacy: .public): guest address not known yet")
            Darwin.close(client)
            return
        }
        let upstream = socket(AF_INET, SOCK_STREAM, 0)
        guard upstream >= 0 else {
            Darwin.close(client)
            return
        }
        _ = fcntl(upstream, F_SETNOSIGPIPE, 1)
        for descriptor in [client, upstream] {
            _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL, 0) | O_NONBLOCK)
            var one: Int32 = 1
            _ = setsockopt(descriptor, IPPROTO_TCP, TCP_NODELAY, &one, socklen_t(MemoryLayout<Int32>.size))
        }
        var target = Self.socketAddress(guestAddress, port: guestPort)
        let result = withUnsafePointer(to: &target) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(upstream, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard result == 0 || errno == EINPROGRESS else {
            Darwin.close(client)
            Darwin.close(upstream)
            return
        }
        let relay = VPhoneStreamRelay(client: client, upstream: upstream, queue: queue)
        let id = ObjectIdentifier(relay)
        relay.onClose = { [weak self] in self?.relays[id] = nil }
        relays[id] = relay
        relay.start(connecting: result != 0)
    }

    // MARK: - UDP

    private func receiveDatagrams(listener: Int32, guestPort: UInt16) {
        var buffer = [UInt8](repeating: 0, count: Self.datagramCapacity)
        while !isStopped {
            var client = sockaddr_in()
            var length = socklen_t(MemoryLayout<sockaddr_in>.size)
            let received = buffer.withUnsafeMutableBytes { raw in
                withUnsafeMutablePointer(to: &client) { pointer in
                    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        recvfrom(listener, raw.baseAddress, raw.count, 0, $0, &length)
                    }
                }
            }
            guard received >= 0 else { return } // EAGAIN: none left
            let payload = Array(buffer[0 ..< received])
            switch destination {
            case let .tunnel(network):
                network.receiveInbound(udp: payload, from: client, listener: listener, guestPort: guestPort)
            case .direct:
                sendDirect(payload, from: client, listener: listener, guestPort: guestPort)
            }
        }
    }

    private func sendDirect(_ payload: [UInt8], from client: sockaddr_in, listener: Int32, guestPort: UInt16) {
        let now = Date()
        for (key, session) in udpSessions where now.timeIntervalSince(session.lastActivity) >= Self.udpIdleTimeout {
            session.source.cancel()
            udpSessions[key] = nil
        }
        let key = "\(listener)|\(client.sin_addr.s_addr)|\(client.sin_port)"
        let session: UDPSession
        if let existing = udpSessions[key] {
            session = existing
        } else {
            guard let created = openUDPSession(client: client, listener: listener, guestPort: guestPort) else { return }
            udpSessions[key] = created
            session = created
        }
        session.lastActivity = now
        _ = payload.withUnsafeBytes { Darwin.send(session.socket, $0.baseAddress, $0.count, 0) }
    }

    /// A socket connected to the guest, so its answers can only come from
    /// there, relayed back to `client` through the listener.
    private func openUDPSession(client: sockaddr_in, listener: Int32, guestPort: UInt16) -> UDPSession? {
        guard let guestAddress else { return nil }
        let descriptor = socket(AF_INET, SOCK_DGRAM, 0)
        guard descriptor >= 0 else { return nil }
        var target = Self.socketAddress(guestAddress, port: guestPort)
        let connected = withUnsafePointer(to: &target) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard connected == 0 else {
            Darwin.close(descriptor)
            return nil
        }
        _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL, 0) | O_NONBLOCK)
        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
        let session = UDPSession(socket: descriptor, source: source)
        source.setEventHandler { [weak session] in
            var buffer = [UInt8](repeating: 0, count: Self.datagramCapacity)
            var client = client
            while true {
                let received = buffer.withUnsafeMutableBytes { recv(descriptor, $0.baseAddress, $0.count, 0) }
                guard received >= 0 else { return }
                session?.lastActivity = Date()
                _ = buffer.withUnsafeBytes { raw in
                    withUnsafePointer(to: &client) { pointer in
                        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                            sendto(listener, raw.baseAddress, received, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                        }
                    }
                }
            }
        }
        source.setCancelHandler { Darwin.close(descriptor) }
        source.resume()
        return session
    }
}

// MARK: - Stream relay

/// Copies bytes both ways between two connected stream sockets until both
/// directions have ended, with backpressure: a side is not read while the
/// other cannot take more. Every call is on `queue`.
final class VPhoneStreamRelay {
    /// Bytes queued toward one side before its peer stops being read.
    private static let pendingLimit = 1 << 20
    private static let readCapacity = 65536

    private let queue: DispatchQueue
    /// `[client, upstream]`. Index `i` reads from `ends[i]`, writes to `ends[1 - i]`.
    private let ends: [Int32]
    private var readSources: [DispatchSourceRead] = []
    private var readSuspended = [false, false]
    private var writeSources: [DispatchSourceWrite?] = [nil, nil]
    /// `pending[i]` waits to be written to `ends[i]`.
    private var pending: [[UInt8]] = [[], []]
    /// `ended[i]`: `ends[i]` will send nothing more.
    private var ended = [false, false]
    private var connectSource: DispatchSourceWrite?
    private var isClosed = false
    private var started = false
    var onClose: (() -> Void)?

    init(client: Int32, upstream: Int32, queue: DispatchQueue) {
        ends = [client, upstream]
        self.queue = queue
    }

    /// Begin relaying, after the upstream connect completes when `connecting`.
    func start(connecting: Bool) {
        guard connecting else {
            begin()
            return
        }
        let source = DispatchSource.makeWriteSource(fileDescriptor: ends[1], queue: queue)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            connectSource?.cancel()
            connectSource = nil
            var error: Int32 = 0
            var length = socklen_t(MemoryLayout<Int32>.size)
            _ = getsockopt(ends[1], SOL_SOCKET, SO_ERROR, &error, &length)
            if error == 0 {
                begin()
            } else {
                close()
            }
        }
        source.resume()
        connectSource = source
    }

    private func begin() {
        guard !isClosed else { return }
        started = true
        for index in 0 ..< 2 {
            let descriptor = ends[index]
            let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
            source.setEventHandler { [weak self] in self?.read(index) }
            source.setCancelHandler { Darwin.close(descriptor) }
            source.resume()
            readSources.append(source)
        }
    }

    private func read(_ index: Int) {
        let other = 1 - index
        var buffer = [UInt8](repeating: 0, count: Self.readCapacity)
        while !isClosed {
            if pending[other].count >= Self.pendingLimit {
                suspendRead(index)
                return
            }
            let received = buffer.withUnsafeMutableBytes { recv(ends[index], $0.baseAddress, $0.count, 0) }
            if received > 0 {
                pending[other] += buffer[0 ..< received]
                flush(other)
                continue
            }
            if received == 0 {
                // Half-close: pass the end along once what came before it has.
                ended[index] = true
                suspendRead(index)
                flush(other)
                return
            }
            if errno != EAGAIN, errno != EINTR {
                close()
            }
            return
        }
    }

    /// Write what `ends[index]` will take; wait for writability for the rest.
    private func flush(_ index: Int) {
        while !pending[index].isEmpty {
            let written = pending[index].withUnsafeBytes { Darwin.send(ends[index], $0.baseAddress, $0.count, 0) }
            if written > 0 {
                pending[index].removeFirst(written)
                continue
            }
            if written < 0, errno == EAGAIN || errno == EINTR {
                if writeSources[index] == nil {
                    let source = DispatchSource.makeWriteSource(fileDescriptor: ends[index], queue: queue)
                    source.setEventHandler { [weak self] in self?.flush(index) }
                    source.resume()
                    writeSources[index] = source
                }
                return
            }
            close()
            return
        }
        writeSources[index]?.cancel()
        writeSources[index] = nil
        let source = 1 - index
        if ended[source] {
            shutdown(ends[index], SHUT_WR)
            if ended[index], pending[source].isEmpty {
                close()
            }
            return
        }
        if readSuspended[source] {
            readSources[source].resume()
            readSuspended[source] = false
        }
    }

    private func suspendRead(_ index: Int) {
        guard !readSuspended[index] else { return }
        readSources[index].suspend()
        readSuspended[index] = true
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        connectSource?.cancel()
        connectSource = nil
        writeSources.forEach { $0?.cancel() }
        writeSources = [nil, nil]
        if started {
            // A suspended source must be resumed before it is cancelled, and
            // the cancel handlers close the descriptors.
            for index in 0 ..< readSources.count {
                if readSuspended[index] {
                    readSources[index].resume()
                    readSuspended[index] = false
                }
                readSources[index].cancel()
            }
        } else {
            ends.forEach { Darwin.close($0) }
        }
        onClose?()
    }
}
