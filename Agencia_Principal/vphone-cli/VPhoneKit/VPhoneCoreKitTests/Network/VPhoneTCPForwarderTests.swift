import Foundation
import Testing
@testable import VPhoneCoreKit

/// Behaviour tests for the TCP forwarder.
///
/// These drive the forwarder the way the frame loop does and play the guest's
/// part, so what is under test is the forwarder's own decisions -- how much it
/// sends, when it sends it again, what it advertises -- against a real host
/// socket on the loopback interface.
///
/// Every bug found against a real guest lived here: a window it did not honour,
/// a retransmission that did not exist, a scale it never negotiated, an upload
/// path that spun instead of waiting. They all passed the frame-level tests in
/// `VPhoneUserspaceNetworkTests`, which is the point of having both.
struct VPhoneTCPForwarderTests {
    // MARK: - Shared plumbing

    /// A mutex box, because the forwarder's callback fires on its own queue and
    /// Swift 6 will not let that touch a captured `var`.
    private final class Box<Value>: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Value

        init(_ value: Value) {
            self.value = value
        }

        func withLock<Result>(_ body: (inout Value) -> Result) -> Result {
            lock.lock()
            defer { lock.unlock() }
            return body(&value)
        }
    }

    /// Plays the guest: hands segments to the forwarder and records what comes
    /// back, exactly as the frame loop's `deliver` would.
    private final class Harness: @unchecked Sendable {
        let forwarder: VPhoneTCPForwarder
        let flow: VPhoneTCPFlow
        let guestPort: UInt16

        private let queue: DispatchQueue
        private let recorded = Box<[VPhoneTCPSegment]>([])
        /// When set, the harness answers every segment the way a guest stack
        /// would: acknowledge at once, window wide open. Used by the tests that
        /// are about the send path rather than about windowing.
        private let acknowledgesImmediately = Box(false)

        init(guestPort: UInt16, destinationPort: UInt16, mss: Int = 1460) {
            self.guestPort = guestPort
            let queue = DispatchQueue(label: "forwarder-tests.\(guestPort)")
            let recorded = recorded
            let acknowledgesImmediately = acknowledgesImmediately
            let flow = VPhoneTCPFlow(
                sourceAddress: VPhoneUserspaceNetworkConfiguration.default.guestAddress,
                sourcePort: guestPort,
                destinationAddress: VPhoneIPv4Address(127, 0, 0, 1),
                destinationPort: destinationPort,
                guestHardware: VPhoneMACAddress([0x02, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE]),
            )
            self.queue = queue
            self.flow = flow

            // The callback needs the forwarder, and the forwarder needs the
            // callback, so the reference goes through a box filled in below.
            let box = Box<VPhoneTCPForwarder?>(nil)
            forwarder = VPhoneTCPForwarder(queue: queue) { _, segment in
                recorded.withLock { $0.append(segment) }
                guard !segment.payload.isEmpty, acknowledgesImmediately.withLock({ $0 }) else { return }
                let acknowledgment = VPhoneTCPSegment(
                    sourcePort: guestPort,
                    destinationPort: 0,
                    sequenceNumber: segment.sequenceNumber,
                    acknowledgmentNumber: segment.sequenceNumber &+ UInt32(segment.payload.count),
                    flags: VPhoneTCPFlags.ack,
                    windowSize: 65535,
                )
                // Async rather than direct: `receive` re-enters the same object,
                // and this way the recursion depth stays bounded.
                queue.async { box.withLock { $0 }?.receive(acknowledgment, for: flow) }
            }
            box.withLock { $0 = forwarder }
            _ = mss
        }

        func acknowledgeImmediately() {
            acknowledgesImmediately.withLock { $0 = true }
        }

        /// What the forwarder has put on the wire, oldest first.
        var sent: [VPhoneTCPSegment] {
            recorded.withLock { $0 }
        }

        /// Our ISN, read off the SYN-ACK the only way any peer could.
        var ourISN: UInt32? {
            sent.first { $0.hasSYN && $0.hasACK }?.sequenceNumber
        }

        /// Bytes of *distinct* sequence numbers. A retransmission repeats a range
        /// rather than extending it, so counting transmissions would overcount.
        var sentDataBytes: Int {
            var unique: [UInt32: Int] = [:]
            for segment in sent where !segment.payload.isEmpty {
                unique[segment.sequenceNumber] = segment.payload.count
            }
            return unique.values.reduce(0, +)
        }

        /// Distinct sequence numbers and their sizes, ascending.
        var dataBySequence: [(sequence: UInt32, count: Int)] {
            var unique: [UInt32: Int] = [:]
            for segment in sent where !segment.payload.isEmpty {
                unique[segment.sequenceNumber] = segment.payload.count
            }
            return unique.sorted { $0.key < $1.key }.map { (sequence: $0.key, count: $0.value) }
        }

        func feed(_ segment: VPhoneTCPSegment) {
            queue.sync { forwarder.receive(segment, for: flow) }
        }

        func start() {
            queue.sync { forwarder.start() }
        }

        func stop() {
            queue.sync { forwarder.stop() }
        }

        /// Wait for something a background socket is responsible for.
        ///
        /// Polls rather than sleeping a fixed time: the far end of these tests is
        /// a real socket, so there is no moment at which it is known to be done.
        @discardableResult
        func waitUntil(_ what: String, timeout: TimeInterval = 8, _ predicate: () -> Bool) -> Bool {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                if predicate() {
                    return true
                }
                usleep(10000)
            }
            Issue.record("timed out waiting for \(what)")
            return false
        }
    }

    /// A one-connection TCP server on the loopback interface, so the forwarder
    /// has something real to terminate against.
    private final class LoopbackServer: @unchecked Sendable {
        let port: UInt16
        private let listener: Int32
        private let received = Box(0)
        private let finished = Box(false)

        /// - Parameter session: runs with the accepted socket on a background
        ///   queue and owns closing it.
        init(session: @escaping @Sendable (Int32, LoopbackServer) -> Void) throws {
            let descriptor = socket(AF_INET, SOCK_STREAM, 0)
            guard descriptor >= 0 else { throw Error.socketFailed }

            var reuse: Int32 = 1
            setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = 0 // let the kernel choose
            address.sin_addr = in_addr(s_addr: UInt32(0x7F00_0001).bigEndian)
            let bound = withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            guard bound == 0 else { throw Error.bindFailed }
            guard listen(descriptor, 4) == 0 else { throw Error.listenFailed }

            var assigned = sockaddr_in()
            var length = socklen_t(MemoryLayout<sockaddr_in>.size)
            _ = withUnsafeMutablePointer(to: &assigned) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    getsockname(descriptor, $0, &length)
                }
            }
            port = UInt16(bigEndian: assigned.sin_port)
            listener = descriptor

            let server = self
            DispatchQueue.global().async {
                let client = accept(descriptor, nil, nil)
                defer { server.finished.withLock { $0 = true } }
                guard client >= 0 else { return }
                defer { close(client) }
                session(client, server)
            }
        }

        /// Bytes pulled out of the socket by the session.
        var bytesReceived: Int {
            received.withLock { $0 }
        }

        /// Whether the session has returned.
        var isFinished: Bool {
            finished.withLock { $0 }
        }

        /// Read and count everything the guest sends.
        func drain(_ client: Int32) {
            var buffer = [UInt8](repeating: 0, count: 65536)
            while true {
                let read = recv(client, &buffer, buffer.count, 0)
                if read <= 0 {
                    return
                }
                received.withLock { $0 += read }
            }
        }

        /// Read and count, stopping early once `target` bytes have arrived.
        func drain(_ client: Int32, until target: Int) {
            var buffer = [UInt8](repeating: 0, count: 65536)
            while bytesReceived < target {
                let read = recv(client, &buffer, buffer.count, 0)
                if read <= 0 {
                    return
                }
                received.withLock { $0 += read }
            }
        }

        func stop() {
            close(listener)
        }

        enum Error: Swift.Error {
            case socketFailed
            case bindFailed
            case listenFailed
        }
    }

    /// Complete the three-way handshake, returning our ISN.
    @discardableResult
    private func handshake(
        _ harness: Harness,
        guestSequence: UInt32 = 1000,
        window: UInt16 = 65535,
        mss: Int = 1460,
        windowScale: Int? = nil,
    ) throws -> UInt32 {
        harness.feed(VPhoneTCPSegment(
            sourcePort: harness.guestPort,
            destinationPort: harness.flow.destinationPort,
            sequenceNumber: guestSequence,
            acknowledgmentNumber: 0,
            flags: VPhoneTCPFlags.syn,
            windowSize: window,
            maximumSegmentSize: mss,
            windowScale: windowScale,
        ))
        try #require(harness.waitUntil("the SYN-ACK") { harness.ourISN != nil })
        let isn = try #require(harness.ourISN)
        harness.feed(VPhoneTCPSegment(
            sourcePort: harness.guestPort,
            destinationPort: harness.flow.destinationPort,
            sequenceNumber: guestSequence &+ 1,
            acknowledgmentNumber: isn &+ 1,
            flags: VPhoneTCPFlags.ack,
            windowSize: window,
        ))
        return isn
    }

    /// Ask the host for data: a push with the peek byte.
    private func request(_ harness: Harness, acknowledged: UInt32, window: UInt16 = 65535) {
        harness.feed(VPhoneTCPSegment(
            sourcePort: harness.guestPort,
            destinationPort: harness.flow.destinationPort,
            sequenceNumber: 1001,
            acknowledgmentNumber: acknowledged,
            flags: VPhoneTCPFlags.ack | VPhoneTCPFlags.psh,
            windowSize: window,
            payload: [0x41],
        ))
    }

    // MARK: - The guest's window

    /// The window is a promise about how much the guest can take. Sending past
    /// it is how a download stalls halfway: the extra segments are discarded,
    /// nothing is sent again, and both ends sit waiting.
    @Test func `a transfer does not outrun the window the guest advertises`() async throws {
        let total = 5000
        let payload = [UInt8](repeating: 0x5A, count: total)
        let server = try LoopbackServer { client, server in
            var buffer = [UInt8](repeating: 0, count: 4096)
            _ = recv(client, &buffer, buffer.count, 0)
            var sent = 0
            while sent < payload.count {
                let written = payload.withUnsafeBytes { send(client, $0.baseAddress, $0.count, 0) }
                if written <= 0 {
                    break
                }
                sent += written
            }
            server.drain(client)
        }
        defer { server.stop() }

        let harness = Harness(guestPort: 51001, destinationPort: server.port)
        harness.start()
        defer { harness.stop() }

        let window: UInt16 = 2048
        let isn = try handshake(harness, window: window, mss: 1024)
        request(harness, acknowledged: isn &+ 1, window: window)

        try #require(harness.waitUntil("the first burst") { harness.sentDataBytes > 0 })
        try await Task.sleep(for: .seconds(1)) // let it overshoot if it is going to
        let afterFirstWindow = harness.sentDataBytes
        #expect(
            afterFirstWindow <= Int(window),
            "sent \(afterFirstWindow)B into a \(window)B window",
        )
        #expect(afterFirstWindow > 0, "nothing was sent even with the window open")

        // Advance the window; the transfer must resume.
        var acknowledged = isn &+ 1 &+ UInt32(afterFirstWindow)
        for _ in 2 ... 8 {
            // `feed` runs synchronously, so whatever the ACK releases is already
            // sent when it returns. Read the count before it, not after.
            let before = harness.sentDataBytes
            harness.feed(VPhoneTCPSegment(
                sourcePort: harness.guestPort,
                destinationPort: server.port,
                sequenceNumber: 1001 &+ UInt32(afterFirstWindow),
                acknowledgmentNumber: acknowledged,
                flags: VPhoneTCPFlags.ack,
                windowSize: window,
            ))
            harness.waitUntil("more data", timeout: 3) { harness.sentDataBytes > before }
            acknowledged = isn &+ 1 &+ UInt32(harness.sentDataBytes)
            if harness.sentDataBytes >= total {
                break
            }
        }

        #expect(harness.sentDataBytes >= total, "stalled at \(harness.sentDataBytes)B of \(total)B")

        let ordered = harness.dataBySequence
        let contiguous = zip(ordered, ordered.dropFirst()).allSatisfy { previous, next in
            next.sequence == previous.sequence &+ UInt32(previous.count)
        }
        #expect(contiguous, "sequence numbers are not contiguous: \(ordered.map(\.sequence))")
        #expect(ordered.allSatisfy { $0.count <= 1024 }, "a segment exceeded the guest's MSS")
    }

    // MARK: - The upload direction

    /// When the host stops reading, the bytes pile up on this side. The guest has
    /// to be told to stop -- a zero window -- and answering that by spinning
    /// would starve every other flow sharing the queue.
    @Test func `the upload direction applies back pressure instead of spinning`() throws {
        let total = 1 << 20
        let server = try LoopbackServer { client, server in
            sleep(1) // refuse to read, so the socket buffers fill
            server.drain(client, until: total)
        }
        defer { server.stop() }

        let harness = Harness(guestPort: 51002, destinationPort: server.port)
        harness.start()
        defer { harness.stop() }

        let isn = try handshake(harness, mss: 1024)

        let chunk = [UInt8](repeating: 0x42, count: 1240)
        var sequence = UInt32(1001)
        var remaining = total
        let started = Date()
        while remaining > 0 {
            let take = min(chunk.count, remaining)
            harness.feed(VPhoneTCPSegment(
                sourcePort: harness.guestPort,
                destinationPort: server.port,
                sequenceNumber: sequence,
                acknowledgmentNumber: isn &+ 1,
                flags: VPhoneTCPFlags.ack | VPhoneTCPFlags.psh,
                windowSize: 65535,
                payload: Array(chunk.prefix(take)),
            ))
            sequence &+= UInt32(take)
            remaining -= take
        }
        let pushTime = Date().timeIntervalSince(started)

        #expect(
            harness.sent.contains { $0.windowSize == 0 && $0.hasACK },
            "the guest was never told the window shut",
        )
        #expect(
            harness.sent.filter { $0.windowSize > 0 && $0.payload.isEmpty }.count > 1,
            "no window update when the backlog cleared",
        )
        #expect(pushTime < 10, "handing the bytes over blocked for \(String(format: "%.1f", pushTime))s")

        harness.waitUntil("the host to drain", timeout: 20) { server.bytesReceived >= total }
        #expect(server.bytesReceived >= total, "the host only saw \(server.bytesReceived)B")
    }

    // MARK: - Window scaling

    /// Scaling only applies when both ends offer it, so a guest finding no
    /// option 3 in our SYN-ACK must keep its window under 64 KiB however much
    /// buffer it has. That ceiling, divided by the round-trip time, is the most
    /// the connection can ever carry.
    @Test func `window scaling is negotiated and the guest's field read at its true size`() throws {
        // The option survives a round trip before anything else is meaningful.
        let offered = VPhoneTCPSegment(
            sourcePort: 1, destinationPort: 2,
            sequenceNumber: 0, acknowledgmentNumber: 0,
            flags: VPhoneTCPFlags.syn,
            windowSize: 65535,
            advertisedMSS: 1460,
            advertisedWindowScale: 7,
        )
        let encoded = offered.bytes(
            source: VPhoneIPv4Address.any,
            destination: VPhoneIPv4Address.any,
        )
        let decoded = try #require(VPhoneTCPSegment(bytes: encoded))
        #expect(decoded.maximumSegmentSize == 1460, "MSS did not survive the round trip")
        #expect(decoded.windowScale == 7, "window scale did not survive the round trip")
        #expect(encoded[12] >> 4 == 7, "the option list must pad to a 32-bit boundary")

        let total = 400_000
        let blob = [UInt8](repeating: 0x21, count: 65536)
        let server = try LoopbackServer { client, server in
            var buffer = [UInt8](repeating: 0, count: 4096)
            _ = recv(client, &buffer, buffer.count, 0)
            var sent = 0
            while sent < total {
                let written = blob.withUnsafeBytes { raw in
                    send(client, raw.baseAddress, min(raw.count, total - sent), 0)
                }
                if written <= 0 {
                    break
                }
                sent += written
            }
            server.drain(client)
        }
        defer { server.stop() }

        let harness = Harness(guestPort: 51003, destinationPort: server.port)
        harness.start()
        defer { harness.stop() }

        // A guest that offers scaling, then advertises a window field of 512 --
        // which at scale 7 means 64 KiB, not 512 bytes.
        let isn = try handshake(harness, windowScale: 7)
        let synAck = try #require(harness.sent.first { $0.hasSYN && $0.hasACK })
        #expect(synAck.advertisedWindowScale == 7, "we did not offer scaling back")

        harness.feed(VPhoneTCPSegment(
            sourcePort: harness.guestPort,
            destinationPort: server.port,
            sequenceNumber: 1001,
            acknowledgmentNumber: isn &+ 1,
            flags: VPhoneTCPFlags.ack | VPhoneTCPFlags.psh,
            windowSize: 512,
            payload: [0x41],
            windowScale: 7,
        ))

        try #require(harness.waitUntil("a scaled window's worth") { harness.sentDataBytes > 512 * 8 })
        #expect(
            harness.sentDataBytes > 512,
            "a scaled window was read as \(harness.sentDataBytes)B, i.e. unscaled",
        )
    }

    // MARK: - Retransmission

    /// A segment the guest never acknowledges stops the connection where it
    /// stands. The link to the guest drops nothing by itself, but that is not the
    /// only way a segment goes unacknowledged, and with no copy kept there is
    /// nothing to send again -- the peer just waits for a timeout.
    @Test func `data the guest does not acknowledge is sent again`() throws {
        let payload = [UInt8](repeating: 0x77, count: 4000)
        let server = try LoopbackServer { client, server in
            var buffer = [UInt8](repeating: 0, count: 4096)
            _ = recv(client, &buffer, buffer.count, 0)
            _ = payload.withUnsafeBytes { send(client, $0.baseAddress, $0.count, 0) }
            server.drain(client)
        }
        defer { server.stop() }

        let harness = Harness(guestPort: 51004, destinationPort: server.port)
        harness.start()
        defer { harness.stop() }

        let isn = try handshake(harness)
        request(harness, acknowledged: isn &+ 1) // and never acknowledge the reply

        try #require(harness.waitUntil("the first data") { harness.sentDataBytes > 0 })
        let nudged = harness.waitUntil("the data to be sent again", timeout: 6) {
            var counts: [UInt32: Int] = [:]
            for segment in harness.sent where !segment.payload.isEmpty {
                counts[segment.sequenceNumber, default: 0] += 1
            }
            return counts.values.contains { $0 > 1 }
        }
        #expect(nudged, "nothing was ever sent twice, so a lost segment would stall forever")
    }

    // MARK: - Throughput

    /// The send path should not be the limit. Not a benchmark -- a guard that a
    /// change to windowing or retransmission has not made it one.
    @Test func `a promptly acknowledging guest gets the payload fast`() throws {
        let total = 4 << 20
        let blob = [UInt8](repeating: 0x33, count: 65536)
        let server = try LoopbackServer { client, server in
            var buffer = [UInt8](repeating: 0, count: 4096)
            _ = recv(client, &buffer, buffer.count, 0)
            var sent = 0
            while sent < total {
                let written = blob.withUnsafeBytes { raw in
                    send(client, raw.baseAddress, min(raw.count, total - sent), 0)
                }
                if written <= 0 {
                    break
                }
                sent += written
            }
            server.drain(client, until: total)
        }
        defer { server.stop() }

        let harness = Harness(guestPort: 51005, destinationPort: server.port)
        harness.acknowledgeImmediately()
        harness.start()
        defer { harness.stop() }

        let isn = try handshake(harness)
        request(harness, acknowledged: isn &+ 1)

        let started = Date()
        harness.waitUntil("the payload", timeout: 25) { harness.sentDataBytes >= total }
        let elapsed = max(Date().timeIntervalSince(started), 0.001)
        let kibibytesPerSecond = Double(harness.sentDataBytes) / 1024 / elapsed
        #expect(
            harness.sentDataBytes >= total,
            "stalled at \(harness.sentDataBytes / 1024) KiB of \(total / 1024) KiB",
        )
        #expect(
            kibibytesPerSecond > 2048,
            "the send path only managed \(Int(kibibytesPerSecond)) KiB/s",
        )
    }
}
