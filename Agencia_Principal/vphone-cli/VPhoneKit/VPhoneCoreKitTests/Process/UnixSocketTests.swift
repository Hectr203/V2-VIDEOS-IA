import Darwin
import Foundation
import Testing
@testable import VPhoneCoreKit

/// Connecting to a Unix-domain socket by path, and the errors that tell a
/// stale or missing socket from one that refuses this user.
struct UnixSocketTests {
    @Test func `a path that does not fit sun_path is refused before any socket is made`() {
        let path = "/tmp/" + String(repeating: "a", count: 200)
        #expect(VPhoneUnixSocket.connect(to: path) == .failure(.pathTooLong))
    }

    @Test func `a missing socket file fails to connect with ENOENT`() {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        #expect(VPhoneUnixSocket.connect(to: path) == .failure(.connect(ENOENT)))
    }

    @Test func `a listening socket connects and a closed one is refused`() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString.prefix(8)).sock").path
        try #require(path.utf8.count < 104)
        defer { unlink(path) }

        let server = socket(AF_UNIX, SOCK_STREAM, 0)
        try #require(server >= 0)
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            for (index, byte) in path.utf8.enumerated() {
                buffer[index] = byte
            }
        }
        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(server, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        try #require(bound == 0)
        try #require(listen(server, 1) == 0)

        guard case let .success(fd) = VPhoneUnixSocket.connect(to: path) else {
            Issue.record("A listening socket did not accept the connection")
            close(server)
            return
        }
        close(fd)
        close(server)
        #expect(VPhoneUnixSocket.connect(to: path) == .failure(.connect(ECONNREFUSED)))
    }
}
