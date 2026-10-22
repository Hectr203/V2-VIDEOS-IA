import Foundation
import Testing
@testable import VPhoneCoreKit

/// Tests for the parts of the IP and TCP encodings that the forwarders depend
/// on, kept separate from the frame-level tests because they are about the
/// encoding rather than about anything the loop does with it.
struct VPhoneInternetProtocolTests {
    // MARK: - IP fragmentation

    /// A datagram that does not fit has to be split, not truncated.
    ///
    /// This is what made QUIC unusable at first: the guest advertised a 1280 MTU,
    /// QUIC rode right at that boundary, and a reply with a 1280-byte payload
    /// plus the headers came to 1308. Sending it whole got it dropped, silently,
    /// once per datagram. UDP has no layer above it to chop anything up, so the
    /// splitting has to happen here.
    @Test func `an oversized packet is fragmented rather than dropped`() throws {
        let payload = [UInt8](repeating: 0x5A, count: 3000)
        let packet = VPhoneIPv4Packet(
            source: VPhoneIPv4Address(192, 168, 127, 1),
            destination: VPhoneIPv4Address(192, 168, 127, 3),
            proto: .udp,
            payload: payload,
        )

        let fragments = packet.fragmented(toFit: 1500)
        #expect(fragments.count > 1, "a 3020-byte packet must not go out in one piece")

        for fragment in fragments {
            #expect(fragment.count <= 1500, "a fragment is \(fragment.count)B, over the MTU")
            let parsed = try #require(VPhoneIPv4Packet(bytes: fragment))
            #expect(parsed.isFragment)
        }

        // Every fragment but the last says more are coming, and the offsets walk
        // forward in 8-byte units.
        let parsed = fragments.compactMap { VPhoneIPv4Packet(bytes: $0) }
        #expect(parsed.count == fragments.count, "a fragment did not parse back")
        for fragment in parsed.dropLast() {
            #expect(fragment.moreFragments, "a non-final fragment did not set MF")
        }
        #expect(parsed.last?.moreFragments == false, "the final fragment set MF")

        let reassembled = parsed.flatMap(\.payload)
        #expect(reassembled == payload, "the fragments do not reassemble to the original")
    }

    /// A packet that already fits must not be fragmented -- extra headers for
    /// nothing, and offsets a peer would have to reassemble.
    @Test func `a packet that fits is left alone`() {
        let packet = VPhoneIPv4Packet(
            source: VPhoneIPv4Address(192, 168, 127, 1),
            destination: VPhoneIPv4Address(192, 168, 127, 3),
            proto: .udp,
            payload: [UInt8](repeating: 0x5A, count: 100),
        )
        let fragments = packet.fragmented(toFit: 1500)
        #expect(fragments.count == 1)
        #expect(fragments.first.map { VPhoneIPv4Packet(bytes: $0)?.isFragment } == false)
    }

    /// Each fragment carries its own header checksum, so a reassembling peer can
    /// tell a corrupted piece from a lost one.
    @Test func `each fragment carries a valid checksum`() {
        let packet = VPhoneIPv4Packet(
            source: VPhoneIPv4Address(192, 168, 127, 1),
            destination: VPhoneIPv4Address(192, 168, 127, 3),
            proto: .udp,
            payload: [UInt8](repeating: 0x77, count: 4000),
        )
        for fragment in packet.fragmented(toFit: 1500) {
            #expect(VPhoneIPv4Packet(bytes: fragment) != nil, "a fragment failed its checksum")
        }
    }

    // MARK: - Encodings the forwarders rely on

    /// The checksum has to cover the pseudo-header, or a peer rejects every
    /// segment. TCP and UDP differ only in the protocol number.
    @Test func `the TCP checksum covers the pseudo-header`() {
        let source = VPhoneIPv4Address(192, 168, 127, 3)
        let destination = VPhoneIPv4Address(142, 250, 1, 1)
        let segment = VPhoneTCPSegment(
            sourcePort: 51000,
            destinationPort: 443,
            sequenceNumber: 1234,
            acknowledgmentNumber: 5678,
            flags: VPhoneTCPFlags.ack | VPhoneTCPFlags.psh,
            windowSize: 65535,
            payload: Array("hello".utf8),
        )
        let bytes = segment.bytes(source: source, destination: destination)
        let pseudo = VPhoneInternetChecksum.pseudoHeader(
            source: source,
            destination: destination,
            proto: VPhoneIPProtocol.tcp.rawValue,
            length: bytes.count,
        )
        #expect(VPhoneInternetChecksum.compute(bytes, seed: pseudo) == 0, "checksum does not verify")
    }

    /// Window scaling has to survive the option encoding, and the option list has
    /// to pad to a 32-bit boundary or the data offset is wrong.
    @Test func `TCP options round trip and pad to a word boundary`() throws {
        let segment = VPhoneTCPSegment(
            sourcePort: 1,
            destinationPort: 2,
            sequenceNumber: 0,
            acknowledgmentNumber: 0,
            flags: VPhoneTCPFlags.syn,
            windowSize: 65535,
            advertisedMSS: 1460,
            advertisedWindowScale: 7,
        )
        let bytes = segment.bytes(source: .any, destination: .any)
        #expect(bytes[12] >> 4 == 7, "the header should be 28 bytes, i.e. 7 words")

        let parsed = try #require(VPhoneTCPSegment(bytes: bytes))
        #expect(parsed.maximumSegmentSize == 1460)
        #expect(parsed.windowScale == 7)
    }
}
