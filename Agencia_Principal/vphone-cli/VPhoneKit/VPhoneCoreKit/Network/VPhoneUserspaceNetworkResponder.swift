import Foundation

// MARK: - ARP

struct VPhoneARPMessage {
    var operation: UInt16
    var senderHardware: VPhoneMACAddress
    var senderProtocol: VPhoneIPv4Address
    var targetHardware: VPhoneMACAddress
    var targetProtocol: VPhoneIPv4Address

    static let ethernetIPv4 = (hardwareType: UInt16(1), protocolType: UInt16(0x0800), hardwareLength: UInt8(6), protocolLength: UInt8(4))
    static let request: UInt16 = 1
    static let reply: UInt16 = 2

    var bytes: [UInt8] {
        var out: [UInt8] = [
            UInt8(Self.ethernetIPv4.hardwareType >> 8), UInt8(truncatingIfNeeded: Self.ethernetIPv4.hardwareType),
            UInt8(Self.ethernetIPv4.protocolType >> 8), UInt8(truncatingIfNeeded: Self.ethernetIPv4.protocolType),
            Self.ethernetIPv4.hardwareLength, Self.ethernetIPv4.protocolLength,
            UInt8(operation >> 8), UInt8(truncatingIfNeeded: operation),
        ]
        out += senderHardware.bytes + senderProtocol.bytes
        out += targetHardware.bytes + targetProtocol.bytes
        return out
    }

    init(operation: UInt16, senderHardware: VPhoneMACAddress, senderProtocol: VPhoneIPv4Address,
         targetHardware: VPhoneMACAddress, targetProtocol: VPhoneIPv4Address)
    {
        self.operation = operation
        self.senderHardware = senderHardware
        self.senderProtocol = senderProtocol
        self.targetHardware = targetHardware
        self.targetProtocol = targetProtocol
    }

    init?(bytes: [UInt8]) {
        guard bytes.count >= 28, bytes[0] == 0, bytes[1] == 1, bytes[2] == 0x08, bytes[3] == 0x00,
              bytes[4] == 6, bytes[5] == 4
        else { return nil }
        operation = UInt16(bytes[6]) << 8 | UInt16(bytes[7])
        senderHardware = VPhoneMACAddress(Array(bytes[8 ..< 14]))
        senderProtocol = VPhoneIPv4Address(
            UInt32(bytes[14]) << 24 | UInt32(bytes[15]) << 16 | UInt32(bytes[16]) << 8 | UInt32(bytes[17]),
        )
        targetHardware = VPhoneMACAddress(Array(bytes[18 ..< 24]))
        targetProtocol = VPhoneIPv4Address(
            UInt32(bytes[24]) << 24 | UInt32(bytes[25]) << 16 | UInt32(bytes[26]) << 8 | UInt32(bytes[27]),
        )
    }
}

// MARK: - DHCP

/// The BOOTP/DHCP subset needed to hand one guest one address.
///
/// Only `DISCOVER`/`REQUEST` are understood and only `OFFER`/`ACK` are emitted.
/// No lease is held: the same address is offered every time, which is all a
/// single-guest VM needs and keeps allocation out of the picture.
struct VPhoneDHCPMessage {
    enum MessageType: UInt8 {
        case discover = 1
        case offer = 2
        case request = 3
        case decline = 4
        case ack = 5
        case nak = 6
        case release = 7
    }

    static let serverPort: UInt16 = 67
    static let clientPort: UInt16 = 68
    private static let magicCookie: [UInt8] = [0x63, 0x82, 0x53, 0x63]

    var operation: UInt8
    var transactionID: UInt32
    var clientHardware: VPhoneMACAddress
    var broadcastFlag: Bool
    var options: [UInt8]

    /// The first option 53 we can find, which is the message type.
    var messageType: MessageType? {
        var index = 0
        while index < options.count {
            let code = options[index]
            if code == 255 {
                return nil
            }
            guard index + 1 < options.count else { return nil }
            let length = Int(options[index + 1])
            guard index + 2 + length <= options.count else { return nil }
            if code == 53, length == 1 {
                return MessageType(rawValue: options[index + 2])
            }
            index += 2 + length
        }
        return nil
    }

    init(operation: UInt8, transactionID: UInt32, clientHardware: VPhoneMACAddress,
         broadcastFlag: Bool, options: [UInt8])
    {
        self.operation = operation
        self.transactionID = transactionID
        self.clientHardware = clientHardware
        self.broadcastFlag = broadcastFlag
        self.options = options
    }

    init?(bytes: [UInt8]) {
        guard bytes.count >= 240, bytes[236 ..< 240].elementsEqual(Self.magicCookie) else { return nil }
        operation = bytes[0]
        transactionID = UInt32(bytes[4]) << 24 | UInt32(bytes[5]) << 16 | UInt32(bytes[6]) << 8 | UInt32(bytes[7])
        broadcastFlag = UInt16(bytes[10]) << 8 | UInt16(bytes[11]) != 0
        clientHardware = VPhoneMACAddress(Array(bytes[28 ..< 34]))
        options = Array(bytes[240...])
    }

    /// Build a reply. `assigned` is the address the guest should use.
    static func reply(
        type: MessageType,
        to request: VPhoneDHCPMessage,
        assigned: VPhoneIPv4Address,
        server: VPhoneIPv4Address,
        netmask: VPhoneIPv4Address,
        dnsServers: [VPhoneIPv4Address] = [],
        mtu: Int,
        leaseSeconds: UInt32 = 86400,
    ) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 236)
        out[0] = 2 // BOOTREPLY
        out[1] = 1 // Ethernet
        out[2] = 6 // hardware address length
        out[3] = 0
        out[4] = UInt8(truncatingIfNeeded: request.transactionID >> 24)
        out[5] = UInt8(truncatingIfNeeded: request.transactionID >> 16)
        out[6] = UInt8(truncatingIfNeeded: request.transactionID >> 8)
        out[7] = UInt8(truncatingIfNeeded: request.transactionID)
        // Echo the broadcast flag so a guest that cannot receive unicast before
        // it owns an address still hears us.
        out[10] = request.broadcastFlag ? 0x80 : 0x00
        out[16 ..< 20] = assigned.bytes[...] // yiaddr: the lease
        out[28 ..< 34] = request.clientHardware.bytes[...]
        out += Self.magicCookie

        var options: [UInt8] = []
        func append(_ code: UInt8, _ values: [UInt8]) {
            options += [code, UInt8(values.count)] + values
        }
        append(53, [type.rawValue])
        append(54, server.bytes) // server identifier
        append(51, withUnsafeBytes(of: leaseSeconds.bigEndian, Array.init)) // lease time
        append(1, netmask.bytes) // subnet mask
        append(3, server.bytes) // router
        append(6, (dnsServers.isEmpty ? [server] : dnsServers).flatMap(\.bytes)) // DNS
        append(26, [UInt8(mtu >> 8), UInt8(mtu & 0xFF)]) // interface MTU
        options.append(255)
        // Pad to the minimum BOOTP payload so short replies stay well-formed.
        while (out.count + options.count) < 300 {
            options.append(0)
        }
        return out + options
    }
}

// MARK: - Responder

/// One guest UDP flow, identified by both ends so a reply can be addressed back
/// without keeping a mapping the other way round.
struct VPhoneUDPFlow: Hashable {
    let sourceAddress: VPhoneIPv4Address
    let sourcePort: UInt16
    let destinationAddress: VPhoneIPv4Address
    let destinationPort: UInt16
    /// The guest's MAC, learned from the frame. Carried here so the forwarder can
    /// build a reply without reaching back into the responder.
    let guestHardware: VPhoneMACAddress

    /// Identity as the forwarder keys sessions: one host socket per flow, reused
    /// while both ends stay the same.
    var key: VPhoneUDPFlowKey {
        VPhoneUDPFlowKey(sourceAddress: sourceAddress, sourcePort: sourcePort, destinationAddress: destinationAddress, destinationPort: destinationPort)
    }
}

struct VPhoneUDPFlowKey: Hashable {
    let sourceAddress: VPhoneIPv4Address
    let sourcePort: UInt16
    let destinationAddress: VPhoneIPv4Address
    let destinationPort: UInt16
}

/// What a frame from the guest asks for.
enum VPhoneUserspaceNetworkOutcome {
    /// Send this frame straight back.
    case reply([UInt8])
    /// The frame is a UDP payload for somewhere beyond the guest; the forwarder
    /// owns the answer, which arrives later.
    case forward(flow: VPhoneUDPFlow, payload: [UInt8])
    /// The frame is a TCP segment. TCP is terminated rather than relayed, so the
    /// forwarder keeps the connection and emits segments of its own.
    case forwardTCP(flow: VPhoneTCPFlow, segment: VPhoneTCPSegment)
    /// Nothing to say.
    case drop
}

/// Turns a frame from the guest into at most one frame back.
///
/// Everything here is deliberately pure apart from `guestMAC`, which is learned
/// from the traffic: Virtualization.framework assigns the MAC and does not
/// expose it, so the first frame the guest sends is the only place to find out
/// what it is. That makes the type stateful, which is why the caller owns it
/// behind a serial queue rather than treating it as a free function.
final class VPhoneUserspaceNetworkResponder {
    private let configuration: VPhoneUserspaceNetworkConfiguration
    private(set) var guestMAC: VPhoneMACAddress?

    init(configuration: VPhoneUserspaceNetworkConfiguration) {
        self.configuration = configuration
    }

    var netmask: VPhoneIPv4Address {
        configuration.subnet.mask
    }

    func handle(_ frame: [UInt8]) -> VPhoneUserspaceNetworkOutcome {
        guard let ethernet = VPhoneEthernetFrame(bytes: frame) else { return .drop }
        // Learn (or refresh) the guest's address from anything it sends.
        if ethernet.source != VPhoneMACAddress.gateway {
            guestMAC = ethernet.source
        }
        guard let etherType = VPhoneEtherType(rawValue: ethernet.etherType) else { return .drop }

        switch etherType {
        case .arp:
            guard let message = VPhoneARPMessage(bytes: ethernet.payload) else { return .drop }
            return respondToARP(message).map { .reply($0) } ?? .drop
        case .ipv4:
            guard let packet = VPhoneIPv4Packet(bytes: ethernet.payload) else { return .drop }
            return respondToIPv4(packet)
        }
    }

    // MARK: - ARP

    private func respondToARP(_ message: VPhoneARPMessage) -> [UInt8]? {
        // Only answer for ourselves, and only for requests. A gratuitous
        // announcement needs no reply.
        guard message.operation == VPhoneARPMessage.request,
              message.targetProtocol == configuration.hostAddress
        else { return nil }

        let reply = VPhoneARPMessage(
            operation: VPhoneARPMessage.reply,
            senderHardware: .gateway,
            senderProtocol: configuration.hostAddress,
            targetHardware: message.senderHardware,
            targetProtocol: message.senderProtocol,
        )
        return VPhoneEthernetFrame(
            destination: message.senderHardware,
            source: .gateway,
            etherType: .arp,
            payload: reply.bytes,
        ).bytes
    }

    // MARK: - IPv4

    private func respondToIPv4(_ packet: VPhoneIPv4Packet) -> VPhoneUserspaceNetworkOutcome {
        // A fragment is only part of a datagram, and nothing here reassembles, so
        // acting on it would mean reading an incomplete transport header.
        guard !packet.isFragment else { return .drop }
        guard let proto = VPhoneIPProtocol(rawValue: packet.proto) else { return .drop }
        switch proto {
        case .icmp:
            return respondToICMP(packet).map { .reply($0) } ?? .drop
        case .udp:
            return respondToUDP(packet)
        case .tcp:
            return respondToTCP(packet)
        }
    }

    private func respondToICMP(_ packet: VPhoneIPv4Packet) -> [UInt8]? {
        // Answer pings for the gateway address only. Anything beyond it needs
        // egress, which is a later stage.
        guard packet.destination == configuration.hostAddress,
              packet.payload.count >= 8, packet.payload[0] == 8, packet.payload[1] == 0
        else { return nil }

        var payload = packet.payload
        payload[0] = 0 // echo reply
        payload[1] = 0
        payload[2] = 0
        payload[3] = 0
        let sum = VPhoneInternetChecksum.compute(payload)
        payload[2] = UInt8(sum >> 8)
        payload[3] = UInt8(sum & 0xFF)

        let reply = VPhoneIPv4Packet(
            source: configuration.hostAddress,
            destination: packet.source == .any ? configuration.guestAddress : packet.source,
            proto: .icmp,
            payload: payload,
        )
        return encapsulate(reply.bytes, destinationMAC: guestMAC ?? broadcastMAC)
    }

    private func respondToUDP(_ packet: VPhoneIPv4Packet) -> VPhoneUserspaceNetworkOutcome {
        guard let datagram = VPhoneUDPDatagram(bytes: packet.payload) else { return .drop }

        // DHCP is the one UDP exchange this side finishes itself: the guest is
        // asking us, by definition.
        if let reply = respondToDHCP(packet, datagram) {
            return .reply(reply)
        }

        // Everything else is egress. The answer has to reach the guest, so we
        // need its MAC — and until it has sent something we do not have it.
        guard let guestMAC, packet.source != .any else { return .drop }
        return .forward(
            flow: VPhoneUDPFlow(
                sourceAddress: packet.source,
                sourcePort: datagram.sourcePort,
                destinationAddress: packet.destination,
                destinationPort: datagram.destinationPort,
                guestHardware: guestMAC,
            ),
            payload: datagram.payload,
        )
    }

    /// Our own DHCP server, or nil when this is not a request we answer.
    private func respondToDHCP(_: VPhoneIPv4Packet, _ datagram: VPhoneUDPDatagram) -> [UInt8]? {
        guard datagram.destinationPort == VPhoneDHCPMessage.serverPort,
              let request = VPhoneDHCPMessage(bytes: datagram.payload)
        else { return nil }

        let type: VPhoneDHCPMessage.MessageType
        switch request.messageType {
        case .discover: type = .offer
        case .request: type = .ack
        // DECLINE/RELEASE/INFORM say nothing a single-lease server needs to act
        // on, and unknown types are not ours to answer.
        default: return nil
        }

        let reply = VPhoneDHCPMessage.reply(
            type: type,
            to: request,
            assigned: configuration.guestAddress,
            server: configuration.hostAddress,
            netmask: netmask,
            dnsServers: configuration.advertisedDNSServers,
            mtu: configuration.mtu,
        )
        let replyDatagram = VPhoneUDPDatagram(
            sourcePort: VPhoneDHCPMessage.serverPort,
            destinationPort: VPhoneDHCPMessage.clientPort,
            payload: reply,
        )
        // The guest has no address yet, so a DHCP reply is always broadcast at
        // the IP layer. That is what the BOOTP broadcast flag is for, and every
        // client accepts it.
        let wrapped = VPhoneIPv4Packet(
            source: configuration.hostAddress,
            destination: .broadcast,
            proto: .udp,
            ttl: 16,
            payload: replyDatagram.bytes(source: configuration.hostAddress, destination: .broadcast),
        )
        return encapsulate(wrapped.bytes, destinationMAC: broadcastMAC)
    }

    // MARK: - TCP

    /// Hand the segment to the TCP forwarder, which terminates it.
    ///
    /// Unlike UDP there is no local case to answer here: every guest segment
    /// belongs to a connection the forwarder owns, and it emits whatever comes
    /// back. A segment we cannot attribute to a guest MAC is dropped, since a
    /// reply could not be addressed.
    private func respondToTCP(_ packet: VPhoneIPv4Packet) -> VPhoneUserspaceNetworkOutcome {
        guard let segment = VPhoneTCPSegment(bytes: packet.payload),
              let guestMAC, packet.source != .any
        else { return .drop }
        return .forwardTCP(
            flow: VPhoneTCPFlow(
                sourceAddress: packet.source,
                sourcePort: segment.sourcePort,
                destinationAddress: packet.destination,
                destinationPort: segment.destinationPort,
                guestHardware: guestMAC,
            ),
            segment: segment,
        )
    }

    // MARK: - Framing

    private var broadcastMAC: VPhoneMACAddress {
        VPhoneMACAddress([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])
    }

    private func encapsulate(_ payload: [UInt8], destinationMAC: VPhoneMACAddress) -> [UInt8] {
        VPhoneEthernetFrame(destination: destinationMAC, source: .gateway, etherType: .ipv4, payload: payload).bytes
    }
}
