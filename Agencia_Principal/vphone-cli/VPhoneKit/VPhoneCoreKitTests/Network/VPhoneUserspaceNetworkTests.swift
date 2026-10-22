import Foundation
import Testing
@testable import VPhoneCoreKit

/// Frame-level tests for the userspace network.
///
/// The responder takes a raw Ethernet frame and returns at most one, so the
/// whole DHCP/ARP/ICMP path can be exercised without a VM, without a socket,
/// and without any privilege. That is how the v1.x work was validated too.
struct VPhoneUserspaceNetworkTests {
    private let configuration = VPhoneUserspaceNetworkConfiguration.default
    private let guestMAC = VPhoneMACAddress([0x02, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE])
    private let broadcastMAC = VPhoneMACAddress([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])

    private func responder() -> VPhoneUserspaceNetworkResponder {
        VPhoneUserspaceNetworkResponder(configuration: configuration)
    }

    // MARK: - Frame builders (guest's point of view)

    private func ipv4Frame(
        source: VPhoneIPv4Address,
        destination: VPhoneIPv4Address,
        proto: VPhoneIPProtocol,
        payload: [UInt8],
        destinationMAC: VPhoneMACAddress? = nil,
    ) -> [UInt8] {
        let packet = VPhoneIPv4Packet(source: source, destination: destination, proto: proto, payload: payload)
        return VPhoneEthernetFrame(
            destination: destinationMAC ?? broadcastMAC,
            source: guestMAC,
            etherType: .ipv4,
            payload: packet.bytes,
        ).bytes
    }

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
        return ipv4Frame(
            source: .any,
            destination: .broadcast,
            proto: .udp,
            payload: datagram.bytes(source: .any, destination: .broadcast),
        )
    }

    private func arpFrame(targeting target: VPhoneIPv4Address, operation: UInt16 = VPhoneARPMessage.request) -> [UInt8] {
        let message = VPhoneARPMessage(
            operation: operation,
            senderHardware: guestMAC,
            senderProtocol: configuration.guestAddress,
            targetHardware: VPhoneMACAddress([0, 0, 0, 0, 0, 0]),
            targetProtocol: target,
        )
        return VPhoneEthernetFrame(
            destination: broadcastMAC,
            source: guestMAC,
            etherType: .arp,
            payload: message.bytes,
        ).bytes
    }

    private func icmpEchoFrame(identifier: UInt16 = 0xBEEF, sequence: UInt16 = 1, payload: [UInt8] = Array("vphone".utf8)) -> [UInt8] {
        var message: [UInt8] = [8, 0, 0, 0] // echo request, checksum placeholder
        message += [UInt8(identifier >> 8), UInt8(truncatingIfNeeded: identifier)]
        message += [UInt8(sequence >> 8), UInt8(truncatingIfNeeded: sequence)]
        message += payload
        let sum = VPhoneInternetChecksum.compute(message)
        message[2] = UInt8(sum >> 8)
        message[3] = UInt8(sum & 0xFF)
        return ipv4Frame(
            source: configuration.guestAddress,
            destination: configuration.hostAddress,
            proto: .icmp,
            payload: message,
            destinationMAC: .gateway,
        )
    }

    // MARK: - DHCP

    @Test func `discover gets an offer for the configured address`() throws {
        let reply = try #require(responder().respond(to: dhcpFrame(type: .discover)))
        let ethernet = try #require(VPhoneEthernetFrame(bytes: reply))
        #expect(ethernet.destination == broadcastMAC)

        let packet = try #require(VPhoneIPv4Packet(bytes: ethernet.payload))
        #expect(packet.source == configuration.hostAddress)
        #expect(packet.destination == .broadcast)

        let datagram = try #require(VPhoneUDPDatagram(bytes: packet.payload))
        #expect(datagram.sourcePort == VPhoneDHCPMessage.serverPort)
        #expect(datagram.destinationPort == VPhoneDHCPMessage.clientPort)

        let replyMessage = try #require(VPhoneDHCPMessage(bytes: datagram.payload))
        #expect(replyMessage.operation == 2) // BOOTREPLY
        #expect(replyMessage.messageType == .offer)
        #expect(replyMessage.clientHardware.bytes == guestMAC.bytes)
        // yiaddr, the lease itself.
        #expect(Array(datagram.payload[16 ..< 20]) == configuration.guestAddress.bytes)
    }

    @Test func `request gets an ack`() throws {
        let reply = try #require(responder().respond(to: dhcpFrame(type: .request)))
        let ethernet = try #require(VPhoneEthernetFrame(bytes: reply))
        let packet = try #require(VPhoneIPv4Packet(bytes: ethernet.payload))
        let datagram = try #require(VPhoneUDPDatagram(bytes: packet.payload))
        let replyMessage = try #require(VPhoneDHCPMessage(bytes: datagram.payload))
        #expect(replyMessage.messageType == .ack)
    }

    /// The guest's own address must survive into option 51/1/3/6, or iOS will
    /// apply the lease and then have no route or resolver.
    @Test func `offer carries the addressing options`() throws {
        let reply = try #require(responder().respond(to: dhcpFrame(type: .discover)))
        let ethernet = try #require(VPhoneEthernetFrame(bytes: reply))
        let packet = try #require(VPhoneIPv4Packet(bytes: ethernet.payload))
        let datagram = try #require(VPhoneUDPDatagram(bytes: packet.payload))
        let options = Array(datagram.payload[240...])

        func option(_ code: UInt8) -> [UInt8]? {
            var index = 0
            while index + 1 < options.count, options[index] != 255 {
                let length = Int(options[index + 1])
                guard index + 2 + length <= options.count else { return nil }
                if options[index] == code {
                    return Array(options[(index + 2) ..< (index + 2 + length)])
                }
                index += 2 + length
            }
            return nil
        }

        #expect(option(1) == [255, 255, 255, 0]) // subnet mask
        #expect(option(3) == configuration.hostAddress.bytes) // router
        #expect(option(6) == configuration.hostAddress.bytes) // DNS
        #expect(option(26) == [UInt8(configuration.mtu >> 8), UInt8(configuration.mtu & 0xFF)])
        #expect(option(54) == configuration.hostAddress.bytes) // server identifier
        #expect(option(51)?.count == 4)
    }

    // MARK: - ARP

    @Test func `arp for the gateway is answered with our address`() throws {
        let reply = try #require(responder().respond(to: arpFrame(targeting: configuration.hostAddress)))
        let ethernet = try #require(VPhoneEthernetFrame(bytes: reply))
        #expect(ethernet.destination == guestMAC)
        #expect(ethernet.source == .gateway)

        let message = try #require(VPhoneARPMessage(bytes: ethernet.payload))
        #expect(message.operation == VPhoneARPMessage.reply)
        #expect(message.senderProtocol == configuration.hostAddress)
        #expect(message.senderHardware.bytes == VPhoneMACAddress.gateway.bytes)
        #expect(message.targetHardware.bytes == guestMAC.bytes)
        #expect(message.targetProtocol == configuration.guestAddress)
    }

    /// Anything that is not us must stay silent, so the guest's own address
    /// resolution still works when it asks about a peer.
    @Test func `arp for another address is ignored`() {
        #expect(responder().respond(to: arpFrame(targeting: VPhoneIPv4Address(192, 168, 127, 99))) == nil)
    }

    @Test func `arp reply is not answered`() {
        let frame = arpFrame(targeting: configuration.hostAddress, operation: VPhoneARPMessage.reply)
        #expect(responder().respond(to: frame) == nil)
    }

    // MARK: - ICMP

    @Test func `echo request gets an echo reply`() throws {
        let reply = try #require(responder().respond(to: icmpEchoFrame()))
        let ethernet = try #require(VPhoneEthernetFrame(bytes: reply))
        #expect(ethernet.destination == guestMAC)
        let packet = try #require(VPhoneIPv4Packet(bytes: ethernet.payload))
        #expect(packet.source == configuration.hostAddress)
        #expect(packet.destination == configuration.guestAddress)

        let message = packet.payload
        #expect(message[0] == 0) // echo reply
        #expect(message[1] == 0)
        #expect(Array(message[4 ..< 8]) == [0xBE, 0xEF, 0x00, 0x01]) // id + sequence preserved
        #expect(Array(message[8...]) == Array("vphone".utf8)) // payload preserved
        #expect(VPhoneInternetChecksum.compute(message) == 0) // a valid checksum sums to zero
    }

    @Test func `a ping for someone else is left alone`() {
        let packet = VPhoneIPv4Packet(
            source: configuration.guestAddress,
            destination: VPhoneIPv4Address(1, 1, 1, 1),
            proto: .icmp,
            payload: [8, 0, 0, 0, 0, 1, 0, 1],
        )
        let frame = VPhoneEthernetFrame(
            destination: .gateway, source: guestMAC, etherType: .ipv4, payload: packet.bytes,
        ).bytes
        #expect(responder().respond(to: frame) == nil)
    }

    // MARK: - Framing and checksums

    @Test func `ethernet round trips`() throws {
        let frame = VPhoneEthernetFrame(
            destination: broadcastMAC, source: guestMAC, etherType: .arp, payload: [1, 2, 3, 4],
        )
        let parsed = try #require(VPhoneEthernetFrame(bytes: frame.bytes))
        #expect(parsed.destination.bytes == broadcastMAC.bytes)
        #expect(parsed.source.bytes == guestMAC.bytes)
        #expect(parsed.etherType == VPhoneEtherType.arp.rawValue)
        #expect(parsed.payload == [1, 2, 3, 4])
    }

    @Test func `a truncated frame is rejected rather than crashing`() {
        #expect(VPhoneEthernetFrame(bytes: [0, 1, 2]) == nil)
        #expect(VPhoneIPv4Packet(bytes: [0x45, 0]) == nil)
        #expect(VPhoneARPMessage(bytes: [0, 1, 8]) == nil)
        #expect(VPhoneDHCPMessage(bytes: [UInt8](repeating: 0, count: 240)) == nil) // no magic cookie
        #expect(responder().respond(to: []) == nil)
    }

    /// A built IPv4 header must verify, which is what catches a byte-order slip
    /// in the checksum path before the guest silently drops everything.
    @Test func `ipv4 header checksum verifies`() {
        let packet = VPhoneIPv4Packet(
            source: configuration.hostAddress,
            destination: .broadcast,
            proto: .udp,
            payload: [0x00, 0x43],
        )
        var bytes = packet.bytes
        let stored = UInt16(bytes[10]) << 8 | UInt16(bytes[11])
        bytes[10] = 0
        bytes[11] = 0
        // The IPv4 checksum covers the header only, which is 20 bytes here.
        #expect(VPhoneInternetChecksum.compute(Array(bytes[0 ..< 20])) == stored)
    }

    /// A fragmented packet cannot be answered without reassembly, so it must be
    /// dropped instead of mis-parsed.
    @Test func `a fragment is dropped`() {
        let packet = VPhoneIPv4Packet(
            source: configuration.guestAddress, destination: configuration.hostAddress,
            proto: .icmp, payload: [8, 0, 0, 0, 0, 1, 0, 1],
        )
        var frame = VPhoneEthernetFrame(
            destination: .gateway, source: guestMAC, etherType: .ipv4, payload: packet.bytes,
        ).bytes
        // Set a non-zero fragment offset in the copy the responder sees.
        frame[14 + 6] = 0x00
        frame[14 + 7] = 0x10
        #expect(responder().respond(to: frame) == nil)
    }

    /// The guest MAC is only discoverable from its traffic, so the responder has
    /// to keep it between frames for unicast replies to be addressed correctly.
    @Test func `guest MAC is learned from traffic`() throws {
        let responder = responder()
        _ = responder.respond(to: arpFrame(targeting: configuration.hostAddress))
        let reply = try #require(responder.respond(to: icmpEchoFrame()))
        let ethernet = try #require(VPhoneEthernetFrame(bytes: reply))
        #expect(ethernet.destination.bytes == guestMAC.bytes)
    }

    // MARK: - UDP forwarding

    /// UDP that is not DHCP is egress rather than something this side answers.
    /// The flow it names has to carry both ends and the guest's MAC, because the
    /// answer is built later, by the forwarder, with no access to this type.
    @Test func `UDP for somewhere else becomes a forward`() {
        let responder = responder()
        // Learn the MAC first, the way a real guest's traffic would.
        _ = responder.handle(arpFrame(targeting: configuration.hostAddress))

        let query = VPhoneUDPDatagram(sourcePort: 51000, destinationPort: 53, payload: [0xAB, 0xCD, 0x01, 0x00])
        let frame = ipv4Frame(
            source: configuration.guestAddress,
            destination: configuration.hostAddress,
            proto: .udp,
            payload: query.bytes(source: configuration.guestAddress, destination: configuration.hostAddress),
            destinationMAC: .gateway,
        )

        guard case let .forward(flow, payload) = responder.handle(frame) else {
            Issue.record("expected a forward")
            return
        }
        #expect(flow.sourceAddress == configuration.guestAddress)
        #expect(flow.sourcePort == 51000)
        #expect(flow.destinationAddress == configuration.hostAddress)
        #expect(flow.destinationPort == 53)
        #expect(flow.guestHardware.bytes == guestMAC.bytes)
        #expect(payload == [0xAB, 0xCD, 0x01, 0x00])
    }

    /// DHCP stays local: it is the one UDP exchange this side finishes itself.
    @Test func `DHCP is answered locally, not forwarded`() {
        if case .forward = responder().handle(dhcpFrame(type: .discover)) {
            Issue.record("DHCP should not be forwarded")
        }
    }

    // MARK: - TCP

    private func tcpFrame(_ segment: VPhoneTCPSegment, source: VPhoneIPv4Address, destination: VPhoneIPv4Address) -> [UInt8] {
        let packet = VPhoneIPv4Packet(
            source: source, destination: destination, proto: .tcp,
            payload: segment.bytes(source: source, destination: destination),
        )
        return VPhoneEthernetFrame(destination: .gateway, source: guestMAC, etherType: .ipv4, payload: packet.bytes).bytes
    }

    /// TCP is terminated, not relayed, so the whole segment goes to the
    /// forwarder along with the flow it belongs to.
    @Test func `TCP segment becomes a forwardTCP`() {
        let responder = responder()
        let syn = VPhoneTCPSegment(
            sourcePort: 51000, destinationPort: 80, sequenceNumber: 1000,
            acknowledgmentNumber: 0, flags: VPhoneTCPFlags.syn, windowSize: 65535,
        )
        let frame = tcpFrame(syn, source: configuration.guestAddress, destination: VPhoneIPv4Address(1, 1, 1, 1))

        guard case let .forwardTCP(flow, segment) = responder.handle(frame) else {
            Issue.record("expected a TCP forward")
            return
        }
        #expect(flow.sourcePort == 51000)
        #expect(flow.destinationPort == 80)
        #expect(flow.destinationAddress == VPhoneIPv4Address(1, 1, 1, 1))
        #expect(flow.guestHardware.bytes == guestMAC.bytes)
        #expect(segment.hasSYN)
        #expect(segment.sequenceNumber == 1000)
    }

    // MARK: - TCP segment codec

    @Test func `TCP segment round trips`() throws {
        let segment = VPhoneTCPSegment(
            sourcePort: 40000, destinationPort: 443, sequenceNumber: 0xDEAD_BEEF,
            acknowledgmentNumber: 0x1234_5678, flags: VPhoneTCPFlags.ack | VPhoneTCPFlags.psh,
            windowSize: 65535, payload: [1, 2, 3, 4],
        )
        let parsed = try #require(VPhoneTCPSegment(bytes: segment.bytes(source: configuration.guestAddress, destination: .broadcast)))
        #expect(parsed.sourcePort == 40000)
        #expect(parsed.destinationPort == 443)
        #expect(parsed.sequenceNumber == 0xDEAD_BEEF)
        #expect(parsed.acknowledgmentNumber == 0x1234_5678)
        #expect(parsed.hasACK && parsed.hasFIN == false)
        #expect(parsed.windowSize == 65535)
        #expect(parsed.payload == [1, 2, 3, 4])
    }

    /// The checksum covers the IP pseudo-header, so it only verifies when summed
    /// against the same addresses it was built with.
    @Test func `TCP checksum verifies over the pseudo-header`() {
        let segment = VPhoneTCPSegment(
            sourcePort: 1, destinationPort: 2, sequenceNumber: 3, acknowledgmentNumber: 4,
            flags: VPhoneTCPFlags.ack, windowSize: 100, payload: [9, 9, 9],
        )
        let bytes = segment.bytes(source: configuration.guestAddress, destination: .broadcast)
        let seed = VPhoneInternetChecksum.pseudoHeader(
            source: configuration.guestAddress, destination: .broadcast, proto: 6, length: bytes.count,
        )
        #expect(VPhoneInternetChecksum.compute(bytes, seed: seed) == 0)
    }

    /// A SYN and a FIN each occupy one sequence number, which is what makes the
    /// guest's acknowledgment of our SYN-ACK line up.
    @Test func `SYN and FIN each cost one sequence number`() {
        let syn = VPhoneTCPSegment(sourcePort: 1, destinationPort: 2, sequenceNumber: 0, acknowledgmentNumber: 0, flags: VPhoneTCPFlags.syn, windowSize: 0)
        #expect(syn.sequenceLength == 1)
        let synWithData = VPhoneTCPSegment(sourcePort: 1, destinationPort: 2, sequenceNumber: 0, acknowledgmentNumber: 0, flags: VPhoneTCPFlags.syn, windowSize: 0, payload: [1, 2])
        #expect(synWithData.sequenceLength == 3)
        let plain = VPhoneTCPSegment(sourcePort: 1, destinationPort: 2, sequenceNumber: 0, acknowledgmentNumber: 0, flags: VPhoneTCPFlags.ack, windowSize: 0)
        #expect(plain.sequenceLength == 0)
    }

    /// A header with options still parses; the options are skipped rather than
    /// misread as payload.
    @Test func `TCP header with options is parsed past`() throws {
        var bytes: [UInt8] = [
            0x00, 0x50, 0x01, 0xBB, // 80 -> 443
            0, 0, 0, 1, 0, 0, 0, 1,
            8 << 4, // data offset 8 words = 32 bytes, so 12 bytes of options
            VPhoneTCPFlags.ack, 0xFF, 0xFF, 0, 0, 0, 0,
        ]
        bytes += [UInt8](repeating: 0, count: 12) // the options themselves
        bytes += [0xAA, 0xBB] // payload
        let segment = try #require(VPhoneTCPSegment(bytes: bytes))
        #expect(segment.sourcePort == 80 && segment.destinationPort == 443)
        #expect(segment.payload == [0xAA, 0xBB])
    }

    @Test func `a truncated TCP segment is rejected`() {
        #expect(VPhoneTCPSegment(bytes: [UInt8](repeating: 0, count: 19)) == nil)
    }
}

// MARK: - Test shims

private extension VPhoneUserspaceNetworkResponder {
    /// The frame this responder would send back, or nil when it would send none.
    /// Added when `respond(to:)` became `handle(_:)` returning an outcome, so
    /// the frame-level tests above kept reading the same way.
    func respond(to frame: [UInt8]) -> [UInt8]? {
        if case let .reply(reply) = handle(frame) {
            return reply
        }
        return nil
    }
}
