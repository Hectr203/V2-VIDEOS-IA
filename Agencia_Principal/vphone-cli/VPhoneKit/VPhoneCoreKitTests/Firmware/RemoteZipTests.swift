import Foundation
import Testing
@testable import VPhoneCoreKit

/// Serves `payload` the way a CDN edge would, with a switch for each of the
/// two things that differ between them: whether HEAD names `Accept-Ranges`,
/// and whether a `Range` request gets a 206 or the whole body.
private final class RemoteZipStubProtocol: URLProtocol {
    nonisolated(unsafe) static var payload = Data()
    nonisolated(unsafe) static var advertisesRanges = true
    nonisolated(unsafe) static var servesRanges = true
    nonisolated(unsafe) static var requests: [String] = []

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let method = request.httpMethod ?? "GET"
        let range = request.value(forHTTPHeaderField: "Range")
        Self.requests.append([method, range].compactMap(\.self).joined(separator: " "))

        var status = 200
        var body = Self.payload
        var headers = ["Content-Length": String(Self.payload.count)]
        if Self.advertisesRanges {
            headers["Accept-Ranges"] = "bytes"
        }
        if method != "HEAD", Self.servesRanges, let range,
           case let bounds = range.dropFirst("bytes=".count).split(separator: "-").compactMap({ Int($0) }),
           bounds.count == 2
        {
            status = 206
            body = Self.payload.subdata(in: bounds[0] ..< min(bounds[1] + 1, Self.payload.count))
            headers["Content-Length"] = String(body.count)
            headers["Content-Range"] = "bytes \(bounds[0])-\(bounds[0] + body.count - 1)/\(Self.payload.count)"
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if method != "HEAD" {
            client?.urlProtocol(self, didLoad: body)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("Remote zip", .serialized)
struct RemoteZipTests {
    private let url = URL(string: "https://updates.cdn-apple.com/private-cloud-compute/example")!

    private func session(advertisesRanges: Bool, servesRanges: Bool, payload: Data) -> URLSession {
        RemoteZipStubProtocol.payload = payload
        RemoteZipStubProtocol.advertisesRanges = advertisesRanges
        RemoteZipStubProtocol.servesRanges = servesRanges
        RemoteZipStubProtocol.requests = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RemoteZipStubProtocol.self]
        return URLSession(configuration: configuration)
    }

    /// A one-member zip with the member stored, as an IPSW stores its
    /// BuildManifest. The reader checks no CRC, so the CRC fields stay zero.
    private func zip(name: String, contents: Data) -> Data {
        func le16(_ value: Int) -> [UInt8] {
            [UInt8(value & 0xFF), UInt8(value >> 8 & 0xFF)]
        }
        func le32(_ value: Int) -> [UInt8] {
            le16(value & 0xFFFF) + le16(value >> 16 & 0xFFFF)
        }
        let nameBytes = Array(name.utf8)
        var data: [UInt8] = [0x50, 0x4B, 0x03, 0x04] + le16(20) + le16(0) + le16(0) + le16(0) + le16(0)
            + le32(0) + le32(contents.count) + le32(contents.count) + le16(nameBytes.count) + le16(0)
        data += nameBytes + Array(contents)
        let directoryOffset = data.count
        data += [0x50, 0x4B, 0x01, 0x02] + le16(20) + le16(20) + le16(0) + le16(0) + le16(0) + le16(0)
            + le32(0) + le32(contents.count) + le32(contents.count) + le16(nameBytes.count) + le16(0) + le16(0)
            + le16(0) + le16(0) + le32(0) + le32(0)
        data += nameBytes
        let directorySize = data.count - directoryOffset
        data += [0x50, 0x4B, 0x05, 0x06] + le16(0) + le16(0) + le16(1) + le16(1)
            + le32(directorySize) + le32(directoryOffset) + le16(0)
        return Data(data)
    }

    @Test func `a server that names Accept-Ranges is not probed`() async throws {
        let session = session(advertisesRanges: true, servesRanges: true, payload: Data(count: 100))
        #expect(try await VPhoneRemoteZip.contentLength(of: url, session: session) == 100)
        #expect(RemoteZipStubProtocol.requests == ["HEAD"])
    }

    @Test func `a server that leaves out Accept-Ranges but answers 206 is seekable`() async throws {
        let session = session(advertisesRanges: false, servesRanges: true, payload: Data(count: 100))
        #expect(try await VPhoneRemoteZip.contentLength(of: url, session: session) == 100)
        #expect(RemoteZipStubProtocol.requests == ["HEAD", "GET bytes=0-0"])
    }

    @Test func `a server that ignores Range is refused`() async throws {
        let session = session(advertisesRanges: false, servesRanges: false, payload: Data(count: 100))
        await #expect {
            _ = try await VPhoneRemoteZip.contentLength(of: url, session: session)
        } throws: { error in
            if case .notSeekable? = error as? VPhoneRemoteZip.Error {
                true
            } else {
                false
            }
        }
    }

    @Test func `a member is read from a CDN that leaves out Accept-Ranges`() async throws {
        let manifest = Data("<plist><dict/></plist>".utf8)
        let session = session(advertisesRanges: false, servesRanges: true, payload: zip(name: "BuildManifest.plist", contents: manifest))
        let archive = try await VPhoneRemoteZip.open(url, session: session)
        #expect(try await archive.read(archive.entry(endingWith: "BuildManifest.plist")) == manifest)
        #expect(RemoteZipStubProtocol.requests.first == "HEAD")
        #expect(RemoteZipStubProtocol.requests.dropFirst().allSatisfy { $0.hasPrefix("GET bytes=") })
    }
}
