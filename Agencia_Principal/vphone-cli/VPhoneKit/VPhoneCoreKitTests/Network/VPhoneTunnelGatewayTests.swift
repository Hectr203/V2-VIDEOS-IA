import Foundation
import Testing
@testable import VPhoneCoreKit

/// The tunnel's gateway stands for the Mac: guest connections to it reach the
/// Mac's loopback, and a refused one is refused at once.
struct VPhoneTunnelGatewayTests {
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

    /// A segment from the guest to the gateway.
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

    /// A loopback TCP socket: listening on a free port, or (with `listening`
    /// false) only bound, to find a port nothing listens on.
    private func loopbackSocket(listening: Bool) throws -> (Int32, UInt16) {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr = in_addr(s_addr: UInt32(0x7F00_0001).bigEndian)
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        try withUnsafeMutablePointer(to: &address) { pointer in
            try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                guard bind(descriptor, $0, length) == 0, getsockname(descriptor, $0, &length) == 0 else {
                    throw POSIXError(.EADDRINUSE)
                }
            }
        }
        if listening {
            _ = listen(descriptor, 4)
        }
        return (descriptor, UInt16(bigEndian: address.sin_port))
    }

    @Test func `a guest connection to the gateway reaches the Mac's loopback`() throws {
        let (server, port) = try loopbackSocket(listening: true)
        defer { close(server) }
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

    /// The RST has to acknowledge the guest's SYN, or the guest ignores it and
    /// retries until it times out.
    @Test func `a refused connection resets the guest at once`() throws {
        let (bound, closedPort) = try loopbackSocket(listening: false)
        close(bound)
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
}
