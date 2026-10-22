import Foundation
import os

// MARK: - Flow

/// One guest TCP flow, named by the guest's view of both ends.
struct VPhoneTCPFlow: Hashable {
    let sourceAddress: VPhoneIPv4Address
    let sourcePort: UInt16
    let destinationAddress: VPhoneIPv4Address
    let destinationPort: UInt16
    /// The guest's MAC, learned from the frame, so a reply can be addressed.
    let guestHardware: VPhoneMACAddress

    var key: VPhoneTCPFlowKey {
        VPhoneTCPFlowKey(
            sourceAddress: sourceAddress, sourcePort: sourcePort,
            destinationAddress: destinationAddress, destinationPort: destinationPort,
        )
    }
}

struct VPhoneTCPFlowKey: Hashable {
    let sourceAddress: VPhoneIPv4Address
    let sourcePort: UInt16
    let destinationAddress: VPhoneIPv4Address
    let destinationPort: UInt16
}

// MARK: - Forwarder

/// Terminates the guest's TCP and carries it over an ordinary host socket.
///
/// This is the stage where `tunnel` stops being a shim and becomes a peer: the
/// guest's TCP belongs to us, the server's TCP belongs to the host kernel, and
/// the two sequence spaces are kept apart. That is more work than stage 2's
/// datagram relay, and it is deliberate — the alternative is doing the
/// translation inside the kernel, which needs a utun and therefore privilege.
///
/// Deliberate simplifications, each defensible because the guest-facing link is a
/// local socketpair that neither reorders nor drops:
///
/// - **No options are sent.** No SACK, no timestamps, no window scaling, so the
///   advertised window is capped at 65535. A guest that offers them gets no
///   reply, which is the correct behaviour for a peer that did not.
/// - **No retransmission.** Our writes to the guest do not need it. If one is
///   lost anyway the guest retransmits, and `sequence == expected` handling
///   treats the copy as a duplicate.
/// - **No congestion control.** The path is host memory.
///
/// Threading: every field is touched only on `queue`. The read sources for the
/// host sockets and the frame loop that calls in both run there, so no lock is
/// needed. That is the invariant behind `@unchecked Sendable`.
final class VPhoneTCPForwarder: @unchecked Sendable {
    /// Delivers one segment back toward the guest.
    typealias Deliver = (VPhoneTCPFlow, VPhoneTCPSegment) -> Void

    /// Same rationale as the UDP forwarder: UDP has no teardown, so a timer is
    /// the only bound. TCP does have one, but a peer that vanishes mid-connection
    /// leaves a session behind until this fires.
    private static let idleTimeout: TimeInterval = 120
    /// A ceiling, so a guest that opens sockets in a loop cannot exhaust the
    /// host. Well above what a VM needs.
    private static let maximumConnections = 256
    /// What we tell the guest it may send us before waiting. Fixed: we do not
    /// advertise window scaling, so this is the whole window.
    private static let advertisedWindow: UInt16 = 65535
    /// Largest segment we will send the guest: the DHCP-advertised MTU less the
    /// IPv4 and TCP headers. Sent as option 2 in the SYN-ACK. Keep in step with
    /// `VPhoneUserspaceNetworkConfiguration.default.mtu`.
    private static let ourMSS = 1460
    /// The shift we offer for window scaling, when the guest offers it too.
    ///
    /// A 16-bit window over a path with any latency is the throughput ceiling:
    /// 64 KiB at 100 ms is 640 KiB/s no matter how fast the link is. Offering a
    /// scale lets the guest advertise a window it could not otherwise express,
    /// which is what lets a download run at the link's speed instead of
    /// 65535/RTT.
    private static let ourWindowScaleShift = 7
    /// What to assume when the guest's SYN carries no MSS option. RFC 1122's
    /// floor, chosen so an unadvertised peer never gets an oversized segment.
    private static let defaultPeerMSS = 536
    /// One read at a time from the host. Larger than an MSS on purpose: fewer
    /// syscalls, and the split into segments happens below anyway.
    private static let readCapacity = 65536
    /// Cap on data buffered for a guest whose window is closed. The host socket's
    /// own receive buffer applies backpressure beyond this: we stop draining it,
    /// so the kernel stops acknowledging the server and the server stops sending.
    private static let maxPendingToGuest = 1 << 20
    /// How long to wait for an acknowledgment before sending the data again.
    ///
    /// Has to clear the guest's delayed-acknowledgment timer *and* a round trip
    /// over whatever the host is tunnelling through; WARP alone can be 200 ms,
    /// and retransmitting into a healthy connection wastes the bandwidth this
    /// exists to protect. Still far below the thirty-second client-side timeouts
    /// that a stalled transfer otherwise ends in.
    private static let retransmitInterval: TimeInterval = 1.5
    private static let log = Logger(subsystem: "com.vphone.tunnel", category: "tcp")

    private enum State {
        /// SYN seen, host connect in flight.
        case connecting
        /// Host is connected, SYN-ACK sent, waiting for the guest's ACK.
        case synAcknowledged
        /// Both directions open.
        case established
        /// FIN seen from one side; the other may still have data in flight.
        case closing
        /// Inbound: a host client connected to a forwarded port, our SYN went
        /// to the guest, and its SYN-ACK has not come back.
        case synSent
    }

    private final class Connection {
        let flow: VPhoneTCPFlow
        let socket: Int32
        let readSource: DispatchSourceRead
        /// Fires when the non-blocking connect completes (or fails).
        var writeSource: DispatchSourceWrite?
        var state: State
        /// Next sequence number we will send to the guest.
        var localSequence: UInt32
        /// Next sequence number we expect from the guest.
        var remoteSequence: UInt32
        /// Guest payload that arrived before the host was connected.
        var pendingFromGuest: [UInt8] = []
        /// Set once the guest has sent FIN, so we do not act on it twice.
        var guestClosed = false
        /// Set once we have sent the guest a FIN.
        var hostClosed = false
        var lastActivity = Date()
        /// The guest's MSS from its SYN, or the RFC floor when it sent none.
        /// Every segment we build is split to fit it.
        var peerMSS: Int
        /// How far to shift the guest's window field. Zero unless scaling was
        /// negotiated; reading an unscaled window as if it were scaled would
        /// badly overestimate the room available.
        var peerWindowScale: Int
        /// True when both ends offered window scaling, so our own advertised
        /// window is shifted on the way out and the guest's is shifted on the
        /// way in.
        var windowScaleNegotiated = false

        // MARK: Sending toward the guest

        //
        // The link to the guest is local and does not lose packets, so the only
        // way data can go missing is by sending more than the guest has buffer
        // for. The send side therefore tracks the guest's advertised window and
        // never runs past it. That is not an optimisation: without it the guest
        // drops the overflow silently, never acknowledges it, and the transfer
        // stops dead -- which is what "downloads crawl and then hang" was.

        /// Right edge of the guest's advertised receive window, i.e. the highest
        /// sequence number we may send. Starts at `localSequence` so nothing goes
        /// out until the guest's first ACK says how much room there is.
        var sendWindowRight: UInt32
        /// Earliest sequence number the guest has not acknowledged.
        var sendUna: UInt32
        /// Bytes sent toward the guest that it has never acknowledged. A number
        /// that stays large while nothing moves is the signature of a stalled
        /// transfer: the peer is waiting for a segment we are not sending again.
        var unacknowledgedBytes: Int {
            Int(Int32(bitPattern: localSequence &- sendUna))
        }

        /// When the guest's acknowledgment last moved, so a stalled connection
        /// can be told from a slow one.
        var lastAckAdvance = Date()
        /// Read from the host, not yet sent, because the window had no room.
        var pendingToGuest: [UInt8] = []
        /// A FIN queued behind `pendingToGuest`.
        var pendingFIN = false
        /// Everything sent toward the guest that it has not acknowledged, oldest
        /// first, with the sequence number the first byte went out under.
        ///
        /// Kept because the link not losing packets is not the same as every
        /// segment arriving: one unacknowledged segment stops the connection
        /// where it stands, and nothing here sends it again. That is what turned
        /// a lost segment into a thirty-second timeout.
        var sentNotAcked: [UInt8] = []
        var sentNotAckedSequence: UInt32 = 0
        var retransmitTimer: DispatchSourceTimer?
        /// Set while the host read source is suspended because the buffer above
        /// is full. Sources are level-triggered, so one that is not drained has
        /// to be suspended or it spins.
        var readSuspended = false

        // MARK: Sending toward the host

        //
        // The mirror of the problem above: the host's send buffer can fill too,
        // when the guest uploads faster than the server accepts. Waiting for
        // writability is the only correct response; retrying in a loop would hold
        // the serial queue and stall every other connection with it.

        /// Guest payload not yet written to the host, waiting on its send buffer.
        var pendingToHost: [UInt8] = []
        /// When the connection opened, for the closing summary.
        let openedAt = Date()
        /// Delivered in each direction, for the closing summary.
        var bytesToHost = 0
        var bytesToGuest = 0
        /// Set by `finish`, so a connection is summarised and torn down once.
        var isClosed = false
        /// Set once we have told the guest our window is shut, so a window update
        /// follows the moment the backlog clears.
        var guestWindowClosed = false
        /// Resends an inbound SYN the guest has not answered.
        var handshakeTimer: DispatchSourceTimer?
        var handshakeAttempts = 0

        init(flow: VPhoneTCPFlow, socket: Int32, readSource: DispatchSourceRead, state: State, localSequence: UInt32, remoteSequence: UInt32, peerMSS: Int, peerWindowScale: Int) {
            self.flow = flow
            self.socket = socket
            self.readSource = readSource
            self.state = state
            self.localSequence = localSequence
            self.remoteSequence = remoteSequence
            self.peerMSS = peerMSS
            self.peerWindowScale = peerWindowScale
            sendWindowRight = localSequence
            sendUna = localSequence
        }
    }

    private let queue: DispatchQueue
    private let deliver: Deliver
    private var connections: [VPhoneTCPFlowKey: Connection] = [:]
    private var reaper: DispatchSourceTimer?
    private var isStopped = false
    /// Source of initial sequence numbers. Only has to be unpredictable enough
    /// that two connections to the same peer do not look alike.
    private var sequenceCounter: UInt32 = .random(in: 0 ... UInt32.max)
    /// The last gateway-side port given to an inbound connection.
    private var inboundPortCursor: UInt16 = 40000

    /// Marks `queue` as ours, so `connectionCount` can tell whether it is already
    /// on it rather than deadlocking against itself.
    private static let queueKey = DispatchSpecificKey<Void>()

    /// Connections to this address go to the Mac's loopback instead: the
    /// gateway stands for the Mac, the way 10.0.2.2 does in QEMU's and
    /// VirtualBox's NAT. Nil leaves every destination as it is.
    private let gatewayAddress: VPhoneIPv4Address?

    init(queue: DispatchQueue, gatewayAddress: VPhoneIPv4Address? = nil, deliver: @escaping Deliver) {
        self.queue = queue
        self.gatewayAddress = gatewayAddress
        self.deliver = deliver
        queue.setSpecific(key: Self.queueKey, value: ())
    }

    /// Live connections, for tests and diagnostics.
    ///
    /// The only member callable from any thread: off the queue it hops on, on the
    /// queue it reads directly. Hopping unconditionally is what deadlocked
    /// `start()` in the UDP forwarder.
    var connectionCount: Int {
        if DispatchQueue.getSpecific(key: Self.queueKey) != nil {
            return connections.count
        }
        return queue.sync { connections.count }
    }

    func start() {
        dispatchPrecondition(condition: .onQueue(queue))
        guard !isStopped, reaper == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + Self.idleTimeout, repeating: Self.idleTimeout)
        timer.setEventHandler { [weak self] in self?.reapIdle() }
        timer.resume()
        reaper = timer
    }

    func stop() {
        dispatchPrecondition(condition: .onQueue(queue))
        guard !isStopped else { return }
        isStopped = true
        reaper?.cancel()
        reaper = nil
        for connection in connections.values {
            close(connection)
        }
        connections.removeAll()
    }

    /// Handle one segment from the guest. On `queue`.
    func receive(_ segment: VPhoneTCPSegment, for flow: VPhoneTCPFlow) {
        dispatchPrecondition(condition: .onQueue(queue))
        handle(segment, flow: flow)
    }

    // MARK: - Segment handling

    private func handle(_ segment: VPhoneTCPSegment, flow: VPhoneTCPFlow) {
        guard !isStopped else { return }

        if segment.hasRST {
            if let connection = connections[flow.key] {
                close(connection)
                connections[flow.key] = nil
            }
            return
        }

        if segment.hasSYN, !segment.hasACK {
            openConnection(for: flow, segment: segment)
            return
        }

        guard let connection = connections[flow.key] else {
            // Nothing here knows this flow. A bare ACK is stale; anything else
            // gets a RST so the guest stops waiting.
            if !segment.hasACK || segment.hasFIN || !segment.payload.isEmpty {
                sendReset(for: flow, inReplyTo: segment)
            }
            return
        }
        connection.lastActivity = Date()

        switch connection.state {
        case .connecting:
            // The host has not connected yet, so we cannot answer. Remember the
            // payload; the handshake will flush it.
            if !segment.payload.isEmpty, segment.sequenceNumber == connection.remoteSequence {
                connection.remoteSequence &+= segment.sequenceLength
                connection.pendingFromGuest += segment.payload
            }

        case .synAcknowledged:
            guard segment.hasACK, segment.acknowledgmentNumber == connection.localSequence else { return }
            connection.state = .established
            connection.sendWindowRight = segment.acknowledgmentNumber &+ Self.expand(segment.windowSize, by: connection.peerWindowScale)
            connection.sendUna = segment.acknowledgmentNumber
            flushPending(connection)

        case .synSent:
            completeInbound(connection, segment: segment)

        case .established, .closing:
            consume(segment, connection: connection)
        }
    }

    private func openConnection(for flow: VPhoneTCPFlow, segment: VPhoneTCPSegment) {
        guard connections[flow.key] == nil else { return }
        guard connections.count < Self.maximumConnections else {
            sendReset(for: flow, inReplyTo: segment)
            return
        }

        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            sendReset(for: flow, inReplyTo: segment)
            return
        }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = flow.destinationPort.bigEndian
        let destination = flow.destinationAddress == gatewayAddress ? VPhoneIPv4Address(127, 0, 0, 1) : flow.destinationAddress
        let octets = destination.bytes
        // Network order, as in the UDP forwarder: host order asks for a
        // different address entirely.
        let hostOrder = UInt32(octets[0]) << 24 | UInt32(octets[1]) << 16 | UInt32(octets[2]) << 8 | UInt32(octets[3])
        address.sin_addr = in_addr(s_addr: hostOrder.bigEndian)

        _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL, 0) | O_NONBLOCK)
        // A guest writing to a connection the server already reset makes our
        // `send` raise SIGPIPE, which would take the whole VM process down.
        _ = fcntl(descriptor, F_SETNOSIGPIPE, 1)
        var one: Int32 = 1
        _ = setsockopt(descriptor, IPPROTO_TCP, TCP_NODELAY, &one, socklen_t(MemoryLayout<Int32>.size))

        let readSource = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
        let connection = Connection(
            flow: flow,
            socket: descriptor,
            readSource: readSource,
            state: .connecting,
            localSequence: nextSequence(),
            // A SYN occupies one sequence number.
            remoteSequence: segment.sequenceNumber &+ 1,
            peerMSS: segment.maximumSegmentSize ?? Self.defaultPeerMSS,
            peerWindowScale: segment.windowScale ?? 0,
        )
        connection.windowScaleNegotiated = segment.windowScale != nil
        readSource.setEventHandler { [weak self] in self?.drainHost(connection) }
        // Qualified: the type has its own `close` for tearing a connection down.
        readSource.setCancelHandler { Darwin.close(descriptor) }

        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if connected == 0 {
            // Connected straight away; no need to wait for writability.
            connection.state = .synAcknowledged
            sendSynAcknowledgment(connection)
        } else if errno == EINPROGRESS {
            // Usual case. Writability means the attempt finished, either way.
            let writeSource = DispatchSource.makeWriteSource(fileDescriptor: descriptor, queue: queue)
            writeSource.setEventHandler { [weak self] in self?.finishConnect(connection) }
            writeSource.resume()
            connection.writeSource = writeSource
        } else {
            readSource.cancel()
            sendReset(for: flow, inReplyTo: segment)
            return
        }

        readSource.resume()
        connections[flow.key] = connection
    }

    private func finishConnect(_ connection: Connection) {
        connection.writeSource?.cancel()
        connection.writeSource = nil

        var error: Int32 = 0
        var length = socklen_t(MemoryLayout<Int32>.size)
        _ = getsockopt(connection.socket, SOL_SOCKET, SO_ERROR, &error, &length)
        guard error == 0 else {
            resetGuest(connection)
            finish(connection)
            return
        }
        connection.state = .synAcknowledged
        sendSynAcknowledgment(connection)
    }

    /// Data (or a FIN) in one direction or the other.
    private func consume(_ segment: VPhoneTCPSegment, connection: Connection) {
        // The guest's ACK is also its window advertisement, and therefore the
        // only thing that tells the send side how much room there is. Reading it
        // here is what keeps a transfer moving instead of stalling after the
        // first burst.
        if segment.hasACK {
            connection.sendWindowRight = segment.acknowledgmentNumber &+ Self.expand(segment.windowSize, by: connection.peerWindowScale)
            if Self.isAfter(segment.acknowledgmentNumber, connection.sendUna) {
                connection.sendUna = segment.acknowledgmentNumber
                connection.lastAckAdvance = Date()
            }
            // Release the copy of anything the guest has taken, so a healthy
            // connection holds nothing.
            let acknowledged = Int(Int32(bitPattern: segment.acknowledgmentNumber &- connection.sentNotAckedSequence))
            if acknowledged > 0 {
                let drop = min(acknowledged, connection.sentNotAcked.count)
                connection.sentNotAcked.removeFirst(drop)
                connection.sentNotAckedSequence &+= UInt32(drop)
            }
            flushToGuest(connection)
        }

        if !segment.payload.isEmpty {
            if segment.sequenceNumber == connection.remoteSequence {
                writeToHost(segment.payload, connection: connection)
                connection.remoteSequence &+= UInt32(segment.payload.count)
                // Acknowledge what we just took, so the guest can send more.
                send(.init(
                    sourcePort: connection.flow.destinationPort,
                    destinationPort: connection.flow.sourcePort,
                    sequenceNumber: connection.localSequence,
                    acknowledgmentNumber: connection.remoteSequence,
                    flags: VPhoneTCPFlags.ack,
                    windowSize: advertisedWindowField(connection),
                ), connection: connection)
            } else {
                // Already seen (a duplicate) or out of order. The link to us is a
                // socketpair and does not reorder, so re-acknowledging what we do
                // expect is the right answer to both.
                send(.init(
                    sourcePort: connection.flow.destinationPort,
                    destinationPort: connection.flow.sourcePort,
                    sequenceNumber: connection.localSequence,
                    acknowledgmentNumber: connection.remoteSequence,
                    flags: VPhoneTCPFlags.ack,
                    windowSize: advertisedWindowField(connection),
                ), connection: connection)
            }
        }

        if segment.hasFIN, !connection.guestClosed {
            connection.guestClosed = true
            connection.remoteSequence &+= 1
            // Half-close: the guest is done sending, but still wants our data.
            shutdown(connection.socket, SHUT_WR)
            sendAcknowledgment(connection)
            connection.state = .closing
            finishIfBothClosed(connection)
        }
    }

    /// Tear down only once neither side has anything left to deliver.
    ///
    /// The earlier version closed as soon as a FIN was seen in both directions,
    /// which threw away data still queued for the guest.
    private func finishIfBothClosed(_ connection: Connection) {
        guard connection.hostClosed, connection.guestClosed else { return }
        guard connection.pendingToGuest.isEmpty, !connection.pendingFIN else { return }
        finish(connection)
    }

    /// Send as much queued data as the guest's window allows.
    ///
    /// Two limits apply to every segment: the guest's MSS, so it fits in one MTU,
    /// and the guest's window, so it fits in the guest's buffer. Both were
    /// learned from the guest. Running past either one loses the data silently.
    private func flushToGuest(_ connection: Connection) {
        while !connection.pendingToGuest.isEmpty {
            let room = Int(Int32(bitPattern: connection.sendWindowRight &- connection.localSequence))
            guard room > 0 else { break }
            let chunk = min(room, min(connection.peerMSS, connection.pendingToGuest.count))
            let data = Array(connection.pendingToGuest.prefix(chunk))
            connection.pendingToGuest.removeFirst(chunk)
            connection.bytesToGuest += chunk
            send(.init(
                sourcePort: connection.flow.destinationPort,
                destinationPort: connection.flow.sourcePort,
                sequenceNumber: connection.localSequence,
                acknowledgmentNumber: connection.remoteSequence,
                flags: VPhoneTCPFlags.ack | VPhoneTCPFlags.psh,
                windowSize: advertisedWindowField(connection),
                payload: data,
            ), connection: connection)
        }

        if connection.pendingToGuest.isEmpty, connection.pendingFIN {
            connection.pendingFIN = false
            send(.init(
                sourcePort: connection.flow.destinationPort,
                destinationPort: connection.flow.sourcePort,
                sequenceNumber: connection.localSequence,
                acknowledgmentNumber: connection.remoteSequence,
                flags: VPhoneTCPFlags.ack | VPhoneTCPFlags.fin,
                windowSize: advertisedWindowField(connection),
            ), connection: connection)
            finishIfBothClosed(connection)
            if connection.state == .closing, connection.pendingToGuest.isEmpty {
                return
            }
        }

        // Room again: resume a source that was paused for backpressure.
        if connection.readSuspended, connection.pendingToGuest.count < Self.maxPendingToGuest {
            connection.readSource.resume()
            connection.readSuspended = false
        }
    }

    private func flushPending(_ connection: Connection) {
        guard !connection.pendingFromGuest.isEmpty else { return }
        let payload = connection.pendingFromGuest
        connection.pendingFromGuest = []
        writeToHost(payload, connection: connection)
        sendAcknowledgment(connection)
    }

    private func writeToHost(_ payload: [UInt8], connection: Connection) {
        connection.bytesToHost += payload.count
        connection.pendingToHost += payload
        flushToHost(connection)
    }

    /// Write what we can toward the host, then wait for writability.
    ///
    /// The previous version retried on EAGAIN in a tight loop. That is not a slow
    /// path, it is a hang: the loop never yields, so the serial queue it runs on
    /// stops serving every other connection -- downloads included -- and the CPU
    /// spins until the host's buffer drains.
    private func flushToHost(_ connection: Connection) {
        while !connection.pendingToHost.isEmpty {
            let written = connection.pendingToHost.withUnsafeBytes { raw -> Int in
                guard let base = raw.baseAddress else { return -1 }
                return Darwin.send(connection.socket, base, raw.count, 0)
            }
            if written > 0 {
                connection.pendingToHost.removeFirst(written)
                continue
            }
            if written < 0, errno == EAGAIN || errno == EINTR {
                // Full. Arm a write source and come back when there is room.
                connection.guestWindowClosed = true
                if connection.writeSource == nil {
                    let source = DispatchSource.makeWriteSource(fileDescriptor: connection.socket, queue: queue)
                    source.setEventHandler { [weak self] in self?.flushToHost(connection) }
                    source.resume()
                    connection.writeSource = source
                }
                return
            }
            resetGuest(connection)
            finish(connection)
            return
        }

        // Backlog cleared: stop watching for writability, and reopen the window
        // if the guest was told it had shut.
        if let source = connection.writeSource {
            source.cancel()
            connection.writeSource = nil
        }
        if connection.guestWindowClosed {
            connection.guestWindowClosed = false
            sendAcknowledgment(connection)
        }
    }

    /// The window field we advertise to the guest, in the units the handshake
    /// agreed on.
    ///
    /// Shut while data is still queued toward the host, so the guest stops
    /// sending instead of piling more into a queue that cannot drain; a window
    /// update goes out once the backlog clears (see `flushToHost`).
    private func advertisedWindowField(_ connection: Connection) -> UInt16 {
        let window = connection.pendingToHost.isEmpty ? Self.advertisedWindow : 0
        guard connection.windowScaleNegotiated else { return window }
        return window >> UInt16(Self.ourWindowScaleShift)
    }

    /// Widest window that shift can express.
    private static func expand(_ field: UInt16, by shift: Int) -> UInt32 {
        shift == 0 ? UInt32(field) : UInt32(field) << UInt32(shift)
    }

    // MARK: - Host to guest

    private func drainHost(_ connection: Connection) {
        // Stop draining the host while the guest's window is closed. Leaving the
        // data in the kernel is the point: its receive buffer fills, it stops
        // acknowledging the server, and the server stops sending.
        if connection.pendingToGuest.count >= Self.maxPendingToGuest {
            if !connection.readSuspended {
                connection.readSource.suspend()
                connection.readSuspended = true
            }
            return
        }

        var buffer = [UInt8](repeating: 0, count: Self.readCapacity)
        while true {
            let received = buffer.withUnsafeMutableBytes { raw in
                recv(connection.socket, raw.baseAddress, raw.count, 0)
            }
            if received > 0 {
                connection.lastActivity = Date()
                connection.pendingToGuest += buffer[0 ..< received]
                flushToGuest(connection)
                if connection.pendingToGuest.count >= Self.maxPendingToGuest {
                    break
                }
                continue
            }
            if received == 0 {
                // The host closed. The FIN goes out behind whatever is still
                // queued, so the guest does not see it before the data.
                connection.lastActivity = Date()
                if !connection.hostClosed {
                    connection.hostClosed = true
                    connection.pendingFIN = true
                    flushToGuest(connection)
                }
                finishIfBothClosed(connection)
                return
            }
            // EAGAIN. A real error is indistinguishable here from a closed peer,
            // so treat anything else as the end of the connection.
            if errno != EAGAIN, errno != EINTR {
                resetGuest(connection)
                finish(connection)
            }
            return
        }
    }

    // MARK: - Emitting

    private func sendSynAcknowledgment(_ connection: Connection) {
        send(.init(
            sourcePort: connection.flow.destinationPort,
            destinationPort: connection.flow.sourcePort,
            sequenceNumber: connection.localSequence,
            acknowledgmentNumber: connection.remoteSequence,
            flags: VPhoneTCPFlags.syn | VPhoneTCPFlags.ack,
            windowSize: advertisedWindowField(connection),
            advertisedMSS: Self.ourMSS,
            advertisedWindowScale: connection.windowScaleNegotiated ? Self.ourWindowScaleShift : nil,
        ), connection: connection)
    }

    private func sendAcknowledgment(_ connection: Connection) {
        send(.init(
            sourcePort: connection.flow.destinationPort,
            destinationPort: connection.flow.sourcePort,
            sequenceNumber: connection.localSequence,
            acknowledgmentNumber: connection.remoteSequence,
            flags: VPhoneTCPFlags.ack,
            windowSize: advertisedWindowField(connection),
        ), connection: connection)
    }

    private func send(_ segment: VPhoneTCPSegment, connection: Connection) {
        if !segment.payload.isEmpty {
            if connection.sentNotAcked.isEmpty {
                connection.sentNotAckedSequence = segment.sequenceNumber
            }
            connection.sentNotAcked += segment.payload
            connection.localSequence &+= UInt32(segment.payload.count)
            armRetransmission(connection)
        }
        if segment.hasSYN || segment.hasFIN {
            connection.localSequence &+= 1
        }
        deliver(connection.flow, segment)
    }

    /// Send a copy of already-sent data, without touching our send sequence.
    private func resend(_ data: [UInt8], sequence: UInt32, connection: Connection) {
        deliver(connection.flow, VPhoneTCPSegment(
            sourcePort: connection.flow.destinationPort,
            destinationPort: connection.flow.sourcePort,
            sequenceNumber: sequence,
            acknowledgmentNumber: connection.remoteSequence,
            flags: VPhoneTCPFlags.ack | VPhoneTCPFlags.psh,
            windowSize: advertisedWindowField(connection),
            payload: data,
        ))
    }

    /// Nudge the oldest unacknowledged segment, once.
    ///
    /// Only the oldest, and only one segment's worth. The point is to break a
    /// stall; resending the whole unacknowledged range spends the connection's
    /// bandwidth on copies. That distinction matters because the common case here
    /// is not loss at all -- the link to the guest drops nothing -- but the
    /// guest's acknowledgment simply being late, and a peer that really did lose
    /// something answers with duplicate acknowledgments, which prompt more
    /// nudges.
    private func retransmit(_ connection: Connection) {
        connection.retransmitTimer?.cancel()
        connection.retransmitTimer = nil
        guard !connection.isClosed, !connection.sentNotAcked.isEmpty else { return }

        let count = min(connection.peerMSS, connection.sentNotAcked.count)
        Self.log.info(
            "nudging :\(connection.flow.sourcePort, privacy: .public) with \(count, privacy: .public)B, \(connection.sentNotAcked.count, privacy: .public)B unacknowledged for \(String(format: "%.1f", Date().timeIntervalSince(connection.lastAckAdvance)), privacy: .public)s",
        )
        resend(Array(connection.sentNotAcked[0 ..< count]), sequence: connection.sentNotAckedSequence, connection: connection)
        armRetransmission(connection)
    }

    private func armRetransmission(_ connection: Connection) {
        guard connection.retransmitTimer == nil, !connection.sentNotAcked.isEmpty, !connection.isClosed else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + Self.retransmitInterval)
        timer.setEventHandler { [weak self] in self?.retransmit(connection) }
        timer.resume()
        connection.retransmitTimer = timer
    }

    /// A RST for a connection the guest knows about, numbered so it is
    /// accepted. Before our SYN-ACK the guest is in SYN-SENT and takes a RST
    /// only if it acknowledges its SYN (RFC 793 section 3.4); after it, only if
    /// its sequence number is in the window. A bare `seq 0, ack 0` reset was
    /// dropped either way, so a refused connect left the guest retrying its
    /// SYN until it timed out.
    private func resetGuest(_ connection: Connection) {
        deliver(connection.flow, VPhoneTCPSegment(
            sourcePort: connection.flow.destinationPort,
            destinationPort: connection.flow.sourcePort,
            sequenceNumber: connection.state == .connecting ? 0 : connection.localSequence,
            acknowledgmentNumber: connection.remoteSequence,
            flags: VPhoneTCPFlags.rst | VPhoneTCPFlags.ack,
            windowSize: 0,
        ))
    }

    /// A RST for a flow we are not going to serve.
    private func sendReset(for flow: VPhoneTCPFlow, inReplyTo segment: VPhoneTCPSegment?) {
        // RFC 793 section 3.4: if the offending segment carried an ACK, the reset
        // borrows its acknowledgment number and carries no ACK of its own.
        // Otherwise sequence 0 plus an ACK naming what we did receive.
        let acknowledging = segment?.hasACK == true
        let reset = VPhoneTCPSegment(
            sourcePort: flow.destinationPort,
            destinationPort: flow.sourcePort,
            sequenceNumber: acknowledging ? (segment?.acknowledgmentNumber ?? 0) : 0,
            acknowledgmentNumber: acknowledging
                ? 0
                : (segment.map { $0.sequenceNumber &+ $0.sequenceLength } ?? 0),
            flags: acknowledging ? VPhoneTCPFlags.rst : (VPhoneTCPFlags.rst | VPhoneTCPFlags.ack),
            windowSize: 0,
        )
        deliver(flow, reset)
    }

    /// Tear a connection down and say what it did.
    ///
    /// Idempotent: several paths can decide a connection is finished, and the
    /// earlier version logged and tore down once per decision, which made the
    /// log look like connections were being closed in pairs.
    private func finish(_ connection: Connection) {
        guard !connection.isClosed else { return }
        connection.isClosed = true
        let lifetime = Date().timeIntervalSince(connection.openedAt)
        let sinceAck = Date().timeIntervalSince(connection.lastAckAdvance)
        Self.log.debug(
            "\(connection.flow.destinationAddress, privacy: .public):\(connection.flow.destinationPort, privacy: .public) <- :\(connection.flow.sourcePort, privacy: .public) closed after \(String(format: "%.1f", lifetime), privacy: .public)s  up \(connection.bytesToHost, privacy: .public)B  down \(connection.bytesToGuest, privacy: .public)B  unacked \(connection.unacknowledgedBytes, privacy: .public)B  lastAck \(String(format: "%.1f", sinceAck), privacy: .public)s ago",
        )
        close(connection)
        connections[connection.flow.key] = nil
    }

    private func close(_ connection: Connection) {
        connection.writeSource?.cancel()
        connection.writeSource = nil
        connection.handshakeTimer?.cancel()
        connection.handshakeTimer = nil
        connection.retransmitTimer?.cancel()
        connection.retransmitTimer = nil
        // A suspended source must be resumed before it can be cancelled;
        // libdispatch aborts the process for releasing a suspended object.
        if connection.readSuspended {
            connection.readSource.resume()
            connection.readSuspended = false
        }
        // The cancel handler closes the descriptor, but only once no handler is
        // running, which is what keeps `drainHost` from touching a freed fd.
        connection.readSource.cancel()
    }

    // MARK: - Housekeeping

    private func reapIdle() {
        let now = Date()
        for (key, connection) in connections where now.timeIntervalSince(connection.lastActivity) >= Self.idleTimeout {
            close(connection)
            connections[key] = nil
        }
    }

    /// Wrap-safe TCP sequence comparison: is `a` after `b`?
    private static func isAfter(_ a: UInt32, _ b: UInt32) -> Bool {
        Int32(bitPattern: a &- b) > 0
    }

    private func nextSequence() -> UInt32 {
        // A simple step is enough: it only has to differ between connections.
        sequenceCounter &+= 0x9E37_79B9
        return sequenceCounter
    }
}

// MARK: - Inbound

/// Connections that start on the host: a client reached a forwarded port, and
/// the guest is the one being connected to. The flow keeps the guest's view,
/// so the guest's port is the source and the gateway is the far end, and once
/// the handshake is done every other path above treats it like any other.
extension VPhoneTCPForwarder {
    /// How often an unanswered SYN is sent again, and how many times. A guest
    /// still booting does not answer at all; one with nothing listening sends a
    /// RST, which ends the attempt at once.
    private static let handshakeInterval: TimeInterval = 1
    private static let handshakeAttempts = 5
    /// The gateway-side ports inbound connections use. Above the guest's own
    /// ephemeral range in practice, and only ever seen by the guest.
    private static let inboundPorts: ClosedRange<UInt16> = 40000 ... 59999

    /// Connect `socket`, accepted from a host client, to `guestPort` on the
    /// guest. Takes ownership of the descriptor. On `queue`.
    func openInbound(
        socket descriptor: Int32,
        guestAddress: VPhoneIPv4Address,
        guestPort: UInt16,
        gatewayAddress: VPhoneIPv4Address,
        guestHardware: VPhoneMACAddress,
    ) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard !isStopped, connections.count < Self.maximumConnections,
              let gatewayPort = freeInboundPort(guestAddress: guestAddress, guestPort: guestPort, gatewayAddress: gatewayAddress)
        else {
            Darwin.close(descriptor)
            return
        }

        _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL, 0) | O_NONBLOCK)
        _ = fcntl(descriptor, F_SETNOSIGPIPE, 1)
        var one: Int32 = 1
        _ = setsockopt(descriptor, IPPROTO_TCP, TCP_NODELAY, &one, socklen_t(MemoryLayout<Int32>.size))

        let flow = VPhoneTCPFlow(
            sourceAddress: guestAddress,
            sourcePort: guestPort,
            destinationAddress: gatewayAddress,
            destinationPort: gatewayPort,
            guestHardware: guestHardware,
        )
        let readSource = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
        let connection = Connection(
            flow: flow,
            socket: descriptor,
            readSource: readSource,
            state: .synSent,
            localSequence: nextSequence(),
            remoteSequence: 0,
            peerMSS: Self.defaultPeerMSS,
            peerWindowScale: 0,
        )
        readSource.setEventHandler { [weak self] in self?.drainHost(connection) }
        readSource.setCancelHandler { Darwin.close(descriptor) }
        // Nothing is read from the client until the guest has accepted, or
        // its FIN could reach the guest before our SYN does. Resumed and then
        // suspended, not left inactive, because `close` resumes a suspended
        // source before cancelling it.
        readSource.resume()
        readSource.suspend()
        connection.readSuspended = true
        connections[flow.key] = connection
        sendInboundSyn(connection)
    }

    private func freeInboundPort(
        guestAddress: VPhoneIPv4Address,
        guestPort: UInt16,
        gatewayAddress: VPhoneIPv4Address,
    ) -> UInt16? {
        for _ in Self.inboundPorts {
            inboundPortCursor = inboundPortCursor >= Self.inboundPorts.upperBound
                ? Self.inboundPorts.lowerBound
                : inboundPortCursor + 1
            let key = VPhoneTCPFlowKey(
                sourceAddress: guestAddress, sourcePort: guestPort,
                destinationAddress: gatewayAddress, destinationPort: inboundPortCursor,
            )
            if connections[key] == nil {
                return inboundPortCursor
            }
        }
        return nil
    }

    private func sendInboundSyn(_ connection: Connection) {
        connection.handshakeAttempts += 1
        // A resend reuses the first SYN's sequence number.
        let sequence = connection.handshakeAttempts == 1 ? connection.localSequence : connection.localSequence &- 1
        let syn = VPhoneTCPSegment(
            sourcePort: connection.flow.destinationPort,
            destinationPort: connection.flow.sourcePort,
            sequenceNumber: sequence,
            acknowledgmentNumber: 0,
            flags: VPhoneTCPFlags.syn,
            windowSize: Self.advertisedWindow,
            advertisedMSS: Self.ourMSS,
            advertisedWindowScale: Self.ourWindowScaleShift,
        )
        if connection.handshakeAttempts == 1 {
            send(syn, connection: connection)
        } else {
            deliver(connection.flow, syn)
        }

        connection.handshakeTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + Self.handshakeInterval)
        timer.setEventHandler { [weak self, weak connection] in
            guard let self, let connection, connection.state == .synSent, !connection.isClosed else { return }
            if connection.handshakeAttempts >= Self.handshakeAttempts {
                finish(connection)
            } else {
                sendInboundSyn(connection)
            }
        }
        timer.resume()
        connection.handshakeTimer = timer
    }

    /// The guest's answer to our SYN. A SYN-ACK for it completes the
    /// handshake; anything else is ignored (a RST was handled before here).
    private func completeInbound(_ connection: Connection, segment: VPhoneTCPSegment) {
        guard segment.hasSYN, segment.hasACK, segment.acknowledgmentNumber == connection.localSequence else { return }
        connection.handshakeTimer?.cancel()
        connection.handshakeTimer = nil
        connection.remoteSequence = segment.sequenceNumber &+ 1
        connection.peerMSS = segment.maximumSegmentSize ?? Self.defaultPeerMSS
        connection.peerWindowScale = segment.windowScale ?? 0
        connection.windowScaleNegotiated = segment.windowScale != nil
        // The window in a SYN is never scaled.
        connection.sendWindowRight = segment.acknowledgmentNumber &+ UInt32(segment.windowSize)
        connection.sendUna = segment.acknowledgmentNumber
        connection.sentNotAckedSequence = segment.acknowledgmentNumber
        connection.state = .established
        sendAcknowledgment(connection)
        if connection.readSuspended {
            connection.readSource.resume()
            connection.readSuspended = false
        }
    }
}
