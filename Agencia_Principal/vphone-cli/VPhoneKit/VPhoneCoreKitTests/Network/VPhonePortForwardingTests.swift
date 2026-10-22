import Foundation
import Testing
@testable import VPhoneCoreKit

/// Host ports carried into the guest, over real sockets: the direct relay
/// `nat` uses, and the tunnel's handoff of a host client into its own stack.
struct VPhonePortForwardingTests {
    typealias PortForward = VPhoneVirtualMachineManifest.NetworkConfig.PortForward

    // MARK: - Sockets

    /// A loopback port nobody holds right now.
    private func freePort(_ type: Int32) throws -> UInt16 {
        let descriptor = socket(AF_INET, type, 0)
        defer { close(descriptor) }
        var address = VPhonePortForwarder.socketAddress(VPhoneIPv4Address(127, 0, 0, 1), port: 0)
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        try withUnsafeMutablePointer(to: &address) { pointer in
            try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                guard bind(descriptor, $0, length) == 0, getsockname(descriptor, $0, &length) == 0 else {
                    throw POSIXError(.EADDRINUSE)
                }
            }
        }
        return UInt16(bigEndian: address.sin_port)
    }

    private func boundSocket(_ type: Int32, port: UInt16 = 0) throws -> (Int32, UInt16) {
        let descriptor = socket(AF_INET, type, 0)
        var one: Int32 = 1
        _ = setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &one, socklen_t(MemoryLayout<Int32>.size))
        var address = VPhonePortForwarder.socketAddress(VPhoneIPv4Address(127, 0, 0, 1), port: port)
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        try withUnsafeMutablePointer(to: &address) { pointer in
            try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                guard bind(descriptor, $0, length) == 0, getsockname(descriptor, $0, &length) == 0 else {
                    throw POSIXError(.EADDRINUSE)
                }
            }
        }
        var timeout = timeval(tv_sec: 3, tv_usec: 0)
        _ = setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        return (descriptor, UInt16(bigEndian: address.sin_port))
    }

    private func connectLoopback(_ type: Int32, port: UInt16) throws -> Int32 {
        let descriptor = socket(AF_INET, type, 0)
        var timeout = timeval(tv_sec: 3, tv_usec: 0)
        _ = setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        var address = VPhonePortForwarder.socketAddress(VPhoneIPv4Address(127, 0, 0, 1), port: port)
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard result == 0 else {
            close(descriptor)
            throw POSIXError(.ECONNREFUSED)
        }
        return descriptor
    }

    private func sendString(_ text: String, to descriptor: Int32) {
        _ = Array(text.utf8).withUnsafeBytes { send(descriptor, $0.baseAddress, $0.count, 0) }
    }

    private func receiveString(from descriptor: Int32) -> String? {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let count = recv(descriptor, &buffer, buffer.count, 0)
        return count > 0 ? String(decoding: buffer[0 ..< count], as: UTF8.self) : nil
    }

    // MARK: - Direct (nat)

    /// A client of the host port reaches the "guest" service and hears back,
    /// in both directions, and the end of the stream gets through too.
    @Test func `TCP is relayed to the guest address`() throws {
        let (server, guestPort) = try boundSocket(SOCK_STREAM)
        defer { close(server) }
        #expect(listen(server, 4) == 0)

        let hostPort = try freePort(SOCK_STREAM)
        let forwarder = VPhonePortForwarder(
            forwards: [PortForward(hostPort: Int(hostPort), guestPort: Int(guestPort))],
            destination: .direct(VPhoneIPv4Address(127, 0, 0, 1)),
        )
        #expect(forwarder.start().isEmpty)
        defer { forwarder.stop() }

        let client = try connectLoopback(SOCK_STREAM, port: hostPort)
        defer { close(client) }
        let accepted = accept(server, nil, nil)
        try #require(accepted >= 0, "the relay never reached the guest service")
        defer { close(accepted) }
        var timeout = timeval(tv_sec: 3, tv_usec: 0)
        _ = setsockopt(accepted, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        sendString("hello", to: client)
        #expect(receiveString(from: accepted) == "hello")
        sendString("world", to: accepted)
        #expect(receiveString(from: client) == "world")

        shutdown(client, SHUT_WR)
        var byte: UInt8 = 0
        #expect(recv(accepted, &byte, 1, 0) == 0, "the client's FIN did not reach the guest")
    }

    @Test func `UDP is relayed to the guest address and back`() throws {
        let (server, guestPort) = try boundSocket(SOCK_DGRAM)
        defer { close(server) }

        let hostPort = try freePort(SOCK_DGRAM)
        let forwarder = VPhonePortForwarder(
            forwards: [PortForward(transport: .udp, hostPort: Int(hostPort), guestPort: Int(guestPort))],
            destination: .direct(VPhoneIPv4Address(127, 0, 0, 1)),
        )
        #expect(forwarder.start().isEmpty)
        defer { forwarder.stop() }

        let client = try connectLoopback(SOCK_DGRAM, port: hostPort)
        defer { close(client) }
        sendString("ping", to: client)

        var buffer = [UInt8](repeating: 0, count: 64)
        var from = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let count = withUnsafeMutablePointer(to: &from) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                recvfrom(server, &buffer, buffer.count, 0, $0, &length)
            }
        }
        try #require(count > 0, "the datagram never reached the guest service")
        #expect(String(decoding: buffer[0 ..< count], as: UTF8.self) == "ping")

        _ = Array("pong".utf8).withUnsafeBytes { raw in
            withUnsafePointer(to: &from) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(server, raw.baseAddress, raw.count, 0, $0, length)
                }
            }
        }
        #expect(receiveString(from: client) == "pong")
    }

    /// Before a DHCP guest reports an address there is nowhere to go, so the
    /// client is turned away instead of hanging.
    @Test func `a client is closed while the guest address is unknown`() throws {
        let hostPort = try freePort(SOCK_STREAM)
        let forwarder = VPhonePortForwarder(
            forwards: [PortForward(hostPort: Int(hostPort), guestPort: 22)],
            destination: .direct(nil),
        )
        #expect(forwarder.start().isEmpty)
        defer { forwarder.stop() }

        let client = try connectLoopback(SOCK_STREAM, port: hostPort)
        defer { close(client) }
        var byte: UInt8 = 0
        #expect(recv(client, &byte, 1, 0) <= 0)
    }

    @Test func `a port already taken is reported, not fatal`() throws {
        let (holder, port) = try boundSocket(SOCK_STREAM)
        defer { close(holder) }
        #expect(listen(holder, 1) == 0)
        let forwarder = VPhonePortForwarder(
            forwards: [PortForward(hostPort: Int(port), guestPort: 22)],
            destination: .direct(VPhoneIPv4Address(127, 0, 0, 1)),
        )
        let failures = forwarder.start()
        defer { forwarder.stop() }
        #expect(failures.count == 1)
    }

    // MARK: - Tunnel

    private let guestMAC = VPhoneMACAddress([0x02, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE])

    /// The guest's end of the frame socket pair.
    private final class GuestLink: @unchecked Sendable {
        let descriptor: Int32
        let network: VPhoneUserspaceNetwork

        init() throws {
            var pair: [Int32] = [-1, -1]
            guard socketpair(AF_UNIX, SOCK_DGRAM, 0, &pair) == 0 else { throw POSIXError(.EMFILE) }
            descriptor = pair[0]
            network = try VPhoneUserspaceNetwork(configuration: .default, guestDescriptor: pair[0], hostDescriptor: pair[1])
        }

        func write(_ frame: [UInt8]) {
            _ = frame.withUnsafeBytes { Darwin.send(descriptor, $0.baseAddress, $0.count, 0) }
        }

        /// The next TCP segment toward the guest, skipping anything else.
        func readSegment(timeout: TimeInterval = 3) -> VPhoneTCPSegment? {
            var buffer = [UInt8](repeating: 0, count: 9216)
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                let count = recv(descriptor, &buffer, buffer.count, MSG_DONTWAIT)
                if count > 0,
                   let frame = VPhoneEthernetFrame(bytes: Array(buffer[0 ..< count])),
                   let packet = VPhoneIPv4Packet(bytes: frame.payload),
                   packet.proto == VPhoneIPProtocol.tcp.rawValue,
                   let segment = VPhoneTCPSegment(bytes: packet.payload)
                {
                    return segment
                }
                usleep(5000)
            }
            return nil
        }
    }

    private func guestFrame(_ segment: VPhoneTCPSegment) -> [UInt8] {
        let configuration = VPhoneUserspaceNetworkConfiguration.default
        return VPhoneEthernetFrame(
            destination: .gateway,
            source: guestMAC,
            etherType: .ipv4,
            payload: VPhoneIPv4Packet(
                source: configuration.guestAddress,
                destination: configuration.hostAddress,
                proto: .tcp,
                payload: segment.bytes(source: configuration.guestAddress, destination: configuration.hostAddress),
            ).bytes,
        ).bytes
    }

    /// A host client becomes a connection the guest accepts from the gateway:
    /// SYN out, SYN-ACK back, then data both ways.
    @Test func `a forwarded client reaches the guest through the tunnel`() throws {
        let link = try GuestLink()
        link.network.start()
        defer { link.network.stop() }

        // The guest has to have said something before it can be addressed.
        link.write(guestFrame(VPhoneTCPSegment(
            sourcePort: 50000, destinationPort: 9, sequenceNumber: 1, acknowledgmentNumber: 0,
            flags: VPhoneTCPFlags.rst, windowSize: 0,
        )))

        var pair: [Int32] = [-1, -1]
        try #require(socketpair(AF_UNIX, SOCK_STREAM, 0, &pair) == 0)
        let client = pair[0]
        defer { close(client) }
        var timeout = timeval(tv_sec: 3, tv_usec: 0)
        _ = setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        usleep(50000)
        link.network.acceptInbound(tcp: pair[1], guestPort: 22)

        let syn = try #require(link.readSegment(), "no SYN reached the guest")
        #expect(syn.hasSYN && !syn.hasACK)
        #expect(syn.destinationPort == 22)

        let guestSequence: UInt32 = 7000
        link.write(guestFrame(VPhoneTCPSegment(
            sourcePort: 22, destinationPort: syn.sourcePort,
            sequenceNumber: guestSequence, acknowledgmentNumber: syn.sequenceNumber &+ 1,
            flags: VPhoneTCPFlags.syn | VPhoneTCPFlags.ack, windowSize: 65535, advertisedMSS: 1460,
        )))
        let ack = try #require(link.readSegment(), "the handshake was not completed")
        #expect(ack.hasACK && !ack.hasSYN)
        #expect(ack.acknowledgmentNumber == guestSequence &+ 1)

        sendString("hello", to: client)
        let data = try #require(link.readSegment(), "the client's bytes did not reach the guest")
        #expect(String(decoding: data.payload, as: UTF8.self) == "hello")

        link.write(guestFrame(VPhoneTCPSegment(
            sourcePort: 22, destinationPort: syn.sourcePort,
            sequenceNumber: guestSequence &+ 1, acknowledgmentNumber: data.sequenceNumber &+ UInt32(data.payload.count),
            flags: VPhoneTCPFlags.ack | VPhoneTCPFlags.psh, windowSize: 65535, payload: Array("world".utf8),
        )))
        #expect(receiveString(from: client) == "world")
    }

    /// The gateway stands for the Mac: a guest connection to it lands on the
    /// Mac's loopback.
    @Test func `a guest connection to the gateway reaches the Mac's loopback`() throws {
        let (server, port) = try boundSocket(SOCK_STREAM)
        defer { close(server) }
        #expect(listen(server, 4) == 0)

        let link = try GuestLink()
        link.network.start()
        defer { link.network.stop() }
        link.write(guestFrame(VPhoneTCPSegment(
            sourcePort: 51000, destinationPort: port, sequenceNumber: 100, acknowledgmentNumber: 0,
            flags: VPhoneTCPFlags.syn, windowSize: 65535, advertisedMSS: 1460,
        )))
        let synAck = try #require(link.readSegment(), "no SYN-ACK from the gateway")
        #expect(synAck.hasSYN && synAck.hasACK)
        #expect(synAck.acknowledgmentNumber == 101)
        let accepted = accept(server, nil, nil)
        #expect(accepted >= 0, "nothing reached the Mac's loopback")
        close(accepted)
    }

    /// A refused connection is refused at once: the RST acknowledges the
    /// guest's SYN, or the guest would ignore it and retry until it timed out.
    @Test func `a refused connection resets the guest at once`() throws {
        let closedPort = try freePort(SOCK_STREAM)
        let link = try GuestLink()
        link.network.start()
        defer { link.network.stop() }
        link.write(guestFrame(VPhoneTCPSegment(
            sourcePort: 51001, destinationPort: closedPort, sequenceNumber: 500, acknowledgmentNumber: 0,
            flags: VPhoneTCPFlags.syn, windowSize: 65535,
        )))
        let reset = try #require(link.readSegment(), "no answer to a SYN for a closed port")
        #expect(reset.hasRST && reset.hasACK)
        #expect(reset.acknowledgmentNumber == 501)
    }

    /// Nothing listening in the guest: its RST ends the client's connection.
    @Test func `a guest refusal closes the client`() throws {
        let link = try GuestLink()
        link.network.start()
        defer { link.network.stop() }
        link.write(guestFrame(VPhoneTCPSegment(
            sourcePort: 50000, destinationPort: 9, sequenceNumber: 1, acknowledgmentNumber: 0,
            flags: VPhoneTCPFlags.rst, windowSize: 0,
        )))

        var pair: [Int32] = [-1, -1]
        try #require(socketpair(AF_UNIX, SOCK_STREAM, 0, &pair) == 0)
        let client = pair[0]
        defer { close(client) }
        var timeout = timeval(tv_sec: 3, tv_usec: 0)
        _ = setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        usleep(50000)
        link.network.acceptInbound(tcp: pair[1], guestPort: 23)

        let syn = try #require(link.readSegment())
        link.write(guestFrame(VPhoneTCPSegment(
            sourcePort: 23, destinationPort: syn.sourcePort,
            sequenceNumber: 0, acknowledgmentNumber: syn.sequenceNumber &+ 1,
            flags: VPhoneTCPFlags.rst | VPhoneTCPFlags.ack, windowSize: 0,
        )))
        var byte: UInt8 = 0
        #expect(recv(client, &byte, 1, 0) == 0)
    }
}
