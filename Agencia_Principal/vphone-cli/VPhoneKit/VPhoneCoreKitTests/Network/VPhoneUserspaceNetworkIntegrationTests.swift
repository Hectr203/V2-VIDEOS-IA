import Foundation
import Testing
@testable import VPhoneCoreKit

/// End-to-end tests for the frame loop.
///
/// Where `VPhoneUserspaceNetworkTests` feeds the responder directly, these drive
/// the real thing: a socket pair, a `DispatchSourceRead`, the shared serial
/// queue, and both forwarders behind it.
///
/// That distinction is the point. The frame-loop bugs found against a real guest
/// -- a blocking read that parked the queue so replies were never drained, a
/// `start()` that deadlocked the queue against the forwarders it owns -- passed
/// every direct test and appeared only once a real event loop was involved.
struct VPhoneUserspaceNetworkIntegrationTests {
    private let configuration = VPhoneUserspaceNetworkConfiguration.default
    private let guestMAC = VPhoneMACAddress([0x02, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE])
    private let broadcastMAC = VPhoneMACAddress([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])

    // MARK: - Standing in for the attachment

    /// The guest's end of the socket pair, plus the network under test. Playing
    /// the attachment is all this has to do: write frames in, read frames out.
    private final class GuestLink: @unchecked Sendable {
        let descriptor: Int32
        private let network: VPhoneUserspaceNetwork

        init(configuration: VPhoneUserspaceNetworkConfiguration) throws {
            var pair: [Int32] = [-1, -1]
            guard socketpair(AF_UNIX, SOCK_DGRAM, 0, &pair) == 0 else {
                throw GuestLinkError.socketPairFailed(errno: errno)
            }
            descriptor = pair[0]
            // The network takes ownership of the guest's end through the
            // attachment; we keep using the same descriptor.
            network = try VPhoneUserspaceNetwork(
                configuration: configuration,
                guestDescriptor: pair[0],
                hostDescriptor: pair[1],
            )
        }

        func start() {
            network.start()
        }

        func stop() {
            network.stop()
        }

        /// Put a frame on the wire the way the attachment would.
        func write(_ frame: [UInt8]) {
            _ = frame.withUnsafeBytes { Darwin.send(descriptor, $0.baseAddress, $0.count, 0) }
        }

        /// The next frame, or nil if one does not arrive in time.
        ///
        /// The descriptor is non-blocking, so this polls rather than parking.
        func read(timeout: TimeInterval = 3) -> [UInt8]? {
            var buffer = [UInt8](repeating: 0, count: 9216)
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                let count = recv(descriptor, &buffer, buffer.count, 0)
                if count > 0 {
                    return Array(buffer[0 ..< count])
                }
                usleep(5000)
            }
            return nil
        }

        enum GuestLinkError: Swift.Error { case socketPairFailed(errno: Int32) }
    }

    /// A mutex box, for state a background queue has to touch.
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

    // MARK: - Frames, from the guest's point of view

    private func dhcpFrame(type: VPhoneDHCPMessage.MessageType, transactionID: UInt32 = 0x1234_5678) -> [UInt8] {
        var message = [UInt8](repeating: 0, count: 236)
        message[0] = 1 // BOOTREQUEST
        message[1] = 1 // Ethernet
        message[2] = 6 // hardware address length
        message[4] = UInt8(truncatingIfNeeded: transactionID >> 24)
        message[5] = UInt8(truncatingIfNeeded: transactionID >> 16)
        message[6] = UInt8(truncatingIfNeeded: transactionID >> 8)
        message[7] = UInt8(truncatingIfNeeded: transactionID)
        message[10] = 0x80 // broadcast
        message[28 ..< 34] = guestMAC.bytes[...]
        message += [0x63, 0x82, 0x53, 0x63]
        message += [53, 1, type.rawValue, 255]
        let datagram = VPhoneUDPDatagram(
            sourcePort: VPhoneDHCPMessage.clientPort,
            destinationPort: VPhoneDHCPMessage.serverPort,
            payload: message,
        )
        return VPhoneEthernetFrame(
            destination: broadcastMAC,
            source: guestMAC,
            etherType: .ipv4,
            payload: VPhoneIPv4Packet(
                source: .any,
                destination: .broadcast,
                proto: .udp,
                payload: datagram.bytes(source: .any, destination: .broadcast),
            ).bytes,
        ).bytes
    }

    private func arpFrame() -> [UInt8] {
        let message = VPhoneARPMessage(
            operation: VPhoneARPMessage.request,
            senderHardware: guestMAC,
            senderProtocol: configuration.guestAddress,
            targetHardware: VPhoneMACAddress([0, 0, 0, 0, 0, 0]),
            targetProtocol: configuration.hostAddress,
        )
        return VPhoneEthernetFrame(
            destination: broadcastMAC,
            source: guestMAC,
            etherType: .arp,
            payload: message.bytes,
        ).bytes
    }

    private func icmpEchoFrame(identifier: UInt16 = 0xBEEF, sequence: UInt16 = 1) -> [UInt8] {
        var message: [UInt8] = [8, 0, 0, 0] // echo request, checksum placeholder
        message += [UInt8(identifier >> 8), UInt8(truncatingIfNeeded: identifier)]
        message += [UInt8(sequence >> 8), UInt8(truncatingIfNeeded: sequence)]
        message += Array("vphone".utf8)
        let sum = VPhoneInternetChecksum.compute(message)
        message[2] = UInt8(sum >> 8)
        message[3] = UInt8(sum & 0xFF)
        return VPhoneEthernetFrame(
            destination: .gateway,
            source: guestMAC,
            etherType: .ipv4,
            payload: VPhoneIPv4Packet(
                source: configuration.guestAddress,
                destination: configuration.hostAddress,
                proto: .icmp,
                payload: message,
            ).bytes,
        ).bytes
    }

    // MARK: - Tests

    /// The whole DHCP exchange has to work through the loop, not just through
    /// the responder: the guest cannot reach anything until it has a lease.
    @Test func `a DHCP exchange completes through the real frame loop`() throws {
        let link = try GuestLink(configuration: configuration)
        link.start()
        defer { link.stop() }

        link.write(dhcpFrame(type: .discover))
        let offer = try #require(link.read(), "no offer came back through the loop")
        let offerEthernet = try #require(VPhoneEthernetFrame(bytes: offer))
        let offerPacket = try #require(VPhoneIPv4Packet(bytes: offerEthernet.payload))
        let offerDatagram = try #require(VPhoneUDPDatagram(bytes: offerPacket.payload))
        let offerMessage = try #require(VPhoneDHCPMessage(bytes: offerDatagram.payload))
        #expect(offerMessage.messageType == .offer)

        link.write(dhcpFrame(type: .request))
        let ack = try #require(link.read(), "no ack came back through the loop")
        let ackEthernet = try #require(VPhoneEthernetFrame(bytes: ack))
        let ackPacket = try #require(VPhoneIPv4Packet(bytes: ackEthernet.payload))
        let ackDatagram = try #require(VPhoneUDPDatagram(bytes: ackPacket.payload))
        let ackMessage = try #require(VPhoneDHCPMessage(bytes: ackDatagram.payload))
        #expect(ackMessage.messageType == .ack)
    }

    /// A VM's fixed address replaces the default: the lease, the mask and the
    /// resolvers all come from its configuration.
    @Test func `a configured address is what DHCP hands out`() throws {
        let custom = VPhoneUserspaceNetworkConfiguration(
            hostAddress: VPhoneIPv4Address(10, 20, 0, 1),
            guestAddress: VPhoneIPv4Address(10, 20, 0, 5),
            prefixLength: 16,
            dnsServers: [VPhoneIPv4Address(1, 1, 1, 1), VPhoneIPv4Address(9, 9, 9, 9)],
        )
        let link = try GuestLink(configuration: custom)
        link.start()
        defer { link.stop() }

        link.write(dhcpFrame(type: .discover))
        let offer = try #require(link.read(), "no offer came back through the loop")
        let ethernet = try #require(VPhoneEthernetFrame(bytes: offer))
        let packet = try #require(VPhoneIPv4Packet(bytes: ethernet.payload))
        let datagram = try #require(VPhoneUDPDatagram(bytes: packet.payload))
        #expect(Array(datagram.payload[16 ..< 20]) == [10, 20, 0, 5])
        let options = Array(datagram.payload[240...])
        func option(_ code: UInt8) -> [UInt8]? {
            var index = 0
            while index + 1 < options.count, options[index] != 255 {
                let length = Int(options[index + 1])
                if options[index] == code {
                    return Array(options[(index + 2) ..< (index + 2 + length)])
                }
                index += 2 + length
            }
            return nil
        }
        #expect(option(1) == [255, 255, 0, 0])
        #expect(option(3) == [10, 20, 0, 1])
        #expect(option(6) == [1, 1, 1, 1, 9, 9, 9, 9])
    }

    /// ARP and ICMP come back too -- they are the guest's other two ways of
    /// finding out whether the link is alive at all.
    @Test func `ARP and ping are answered through the real frame loop`() throws {
        let link = try GuestLink(configuration: configuration)
        link.start()
        defer { link.stop() }

        link.write(arpFrame())
        let arp = try #require(link.read(), "ARP went unanswered")
        let arpEthernet = try #require(VPhoneEthernetFrame(bytes: arp))
        #expect(arpEthernet.etherType == VPhoneEtherType.arp.rawValue)

        link.write(icmpEchoFrame())
        let ping = try #require(link.read(), "ping went unanswered")
        let pingEthernet = try #require(VPhoneEthernetFrame(bytes: ping))
        let pingPacket = try #require(VPhoneIPv4Packet(bytes: pingEthernet.payload))
        #expect(pingPacket.proto == VPhoneIPProtocol.icmp.rawValue)
    }

    /// The regression test for the blocking read.
    ///
    /// `drain` loops until `recv` reports EAGAIN and everything shares one serial
    /// queue. On a blocking socket the loop parks in `recv` the moment the guest
    /// goes quiet -- which is exactly when the guest is waiting for a reply, so
    /// the reply is never read. The guest saw DNS queries leave and no answers
    /// come back. Going quiet between exchanges is what makes this test read.
    @Test func `the loop keeps draining after the guest goes quiet`() async throws {
        let link = try GuestLink(configuration: configuration)
        link.start()
        defer { link.stop() }

        for round in 1 ... 3 {
            link.write(dhcpFrame(type: .discover))
            let reply = link.read()
            #expect(reply != nil, "round \(round) went unanswered after a period of silence")
            // Silence is the condition under test.
            try await Task.sleep(for: .milliseconds(700))
        }
    }

    /// The regression test for the start-up deadlock.
    ///
    /// `start()` runs on the network's serial queue and calls into the forwarders
    /// it owns. If any of those hops back onto the same queue with `sync`, the
    /// queue waits on itself and traps. Production hit this immediately; nothing
    /// that called the forwarders directly ever would.
    @Test func `start returns instead of deadlocking against its own forwarders`() throws {
        let link = try GuestLink(configuration: configuration)
        let returned = Box(false)
        DispatchQueue.global().async {
            link.start()
            returned.withLock { $0 = true }
        }

        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline, !returned.withLock({ $0 }) {
            usleep(10000)
        }
        #expect(
            returned.withLock { $0 },
            "start() never returned -- it deadlocked on the queue it shares with its forwarders",
        )
        link.stop()
    }

    /// A stopped network must not answer. Otherwise teardown leaves a source
    /// firing on a closed descriptor.
    @Test func `a stopped network stops answering`() throws {
        let link = try GuestLink(configuration: configuration)
        link.start()
        link.write(dhcpFrame(type: .discover))
        #expect(link.read() != nil, "not answering before stop()")

        link.stop()
        // Drain anything already in flight, then confirm nothing new arrives.
        _ = link.read(timeout: 0.2)
        link.write(dhcpFrame(type: .discover, transactionID: 0x9999))
        #expect(link.read(timeout: 0.5) == nil, "still answering after stop()")
    }
}
