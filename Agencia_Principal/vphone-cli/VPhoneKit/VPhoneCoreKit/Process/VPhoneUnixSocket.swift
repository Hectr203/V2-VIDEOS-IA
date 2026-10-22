import Darwin
import Foundation

// MARK: - Unix Socket

/// A client connection to a Unix-domain stream socket by path: the one place
/// that packs a `sockaddr_un`. Used for a VM's control socket, `vphone.sock`,
/// both to talk to it and to tell a live VM from a stale socket file.
public enum VPhoneUnixSocket {
    public enum ConnectError: Error, Equatable {
        /// The path does not fit `sun_path` with its terminating NUL.
        case pathTooLong
        /// `socket(2)` failed, with its errno.
        case socket(Int32)
        /// `connect(2)` failed, with its errno: ECONNREFUSED for a socket
        /// file nobody listens on, ENOENT for no file, EACCES for one this
        /// user may not write.
        case connect(Int32)
    }

    /// A connected descriptor, which the caller closes. A path too long for
    /// `sun_path` is reached through ``withAddressablePath(_:_:)``.
    public static func connect(to path: String) -> Result<Int32, ConnectError> {
        withAddressablePath(path) { connectDirectly(to: $0) }
    }

    /// The bytes `sun_path` holds, terminating NUL included.
    public static let maximumPathLength = MemoryLayout.size(ofValue: sockaddr_un().sun_path)

    /// Runs `body` with a path to the socket file at `path` that fits
    /// `sun_path`: `path` itself when it does, otherwise the same file reached
    /// through a symbolic link to its folder, in a private (0700) folder under
    /// `/tmp` that is removed afterwards. The kernel follows the link, so a
    /// socket bound or connected through it is the one at `path`. A template
    /// being built lives deep in `.templates/.building-…/`, past the 104 bytes.
    /// When no such folder can be made, `body` gets `path` and fails as before.
    public static func withAddressablePath<T>(_ path: String, _ body: (String) throws -> T) rethrows -> T {
        guard path.utf8CString.count > maximumPathLength else { return try body(path) }
        var template = Array("/tmp/vphone.XXXXXX".utf8CString)
        // mkdtemp returns a pointer into the template, and `&template` lends
        // only a buffer that ends with the call: read the name while it is
        // still pinned.
        let created = template.withUnsafeMutableBufferPointer { buffer in
            mkdtemp(buffer.baseAddress!).map { String(cString: $0) }
        }
        guard let folder = created else { return try body(path) }
        let link = folder + "/d"
        let target = (path as NSString).deletingLastPathComponent
        defer {
            unlink(link)
            rmdir(folder)
        }
        guard symlink(target, link) == 0 else { return try body(path) }
        return try body(link + "/" + (path as NSString).lastPathComponent)
    }

    private static func connectDirectly(to path: String) -> Result<Int32, ConnectError> {
        let bytes = path.utf8CString
        var address = sockaddr_un()
        guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else {
            return .failure(.pathTooLong)
        }
        address.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            for (index, byte) in bytes.enumerated() {
                buffer[index] = UInt8(bitPattern: byte)
            }
        }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return .failure(.socket(errno)) }
        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else {
            let failure = errno
            close(fd)
            return .failure(.connect(failure))
        }
        return .success(fd)
    }
}
