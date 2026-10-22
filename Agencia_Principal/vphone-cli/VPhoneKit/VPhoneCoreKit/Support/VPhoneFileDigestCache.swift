import CryptoKit
import Foundation

/// The SHA-256 of one file, hashed again only when the file's identity, size
/// or modification time changes.
///
/// `vphone-vm` compares the bundled vphoned with the guest's on every health
/// probe, every three seconds while connected. Reading and hashing the 9 MB
/// binary each time was most of an idle VM window's CPU in `vphone-vm`,
/// although the file in an installed bundle never changes while it runs.
public struct VPhoneFileDigestCache: Sendable {
    struct Stamp: Equatable {
        var path: String
        var device: UInt64
        var inode: UInt64
        var size: Int64
        var modifiedSeconds: Int
        var modifiedNanoseconds: Int
    }

    private var stamp: Stamp?
    private var digest: String?
    /// How often the file was read and hashed, for tests.
    public private(set) var hashCount = 0

    public init() {}

    /// The lowercase hex SHA-256 of the file at `url`, or nil when it cannot
    /// be read.
    public mutating func sha256(of url: URL) -> String? {
        guard let current = Self.stamp(of: url) else {
            stamp = nil
            digest = nil
            return nil
        }
        if current == stamp, let digest {
            return digest
        }
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            stamp = nil
            digest = nil
            return nil
        }
        hashCount += 1
        let hex = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        stamp = current
        digest = hex
        return hex
    }

    static func stamp(of url: URL) -> Stamp? {
        var info = stat()
        guard stat(url.path, &info) == 0 else { return nil }
        return Stamp(
            path: url.path,
            device: UInt64(bitPattern: Int64(info.st_dev)),
            inode: UInt64(info.st_ino),
            size: Int64(info.st_size),
            modifiedSeconds: Int(info.st_mtimespec.tv_sec),
            modifiedNanoseconds: Int(info.st_mtimespec.tv_nsec),
        )
    }
}
