import Foundation

/// Log files end lines with a bare line feed, which a terminal treats as
/// "down one row" without returning to the first column; each one gains a
/// carriage return.
///
/// A console can print thousands of lines a second, so a chunk is copied in
/// the runs between line feeds, not byte by byte.
nonisolated struct VPhoneLaunchpadNewlineTranslator {
    private var previous: UInt8 = 0

    mutating func translate(_ data: Data) -> Data {
        guard let last = data.last else {
            return Data()
        }
        var output = Data(capacity: data.count + data.count / 32)
        let previous = previous
        data.withUnsafeBytes { bytes in
            var start = 0
            while let end = Self.lineFeed(in: bytes, from: start) {
                let before = end > 0 ? bytes[end - 1] : previous
                output.append(contentsOf: UnsafeRawBufferPointer(rebasing: bytes[start ..< end]))
                if before != 0x0D {
                    output.append(0x0D)
                }
                output.append(0x0A)
                start = end + 1
            }
            output.append(contentsOf: UnsafeRawBufferPointer(rebasing: bytes[start...]))
        }
        self.previous = last
        return output
    }

    /// The offset of the next line feed at or after `start`.
    private static func lineFeed(in bytes: UnsafeRawBufferPointer, from start: Int) -> Int? {
        guard start < bytes.count, let base = bytes.baseAddress,
              let found = memchr(base + start, 0x0A, bytes.count - start)
        else {
            return nil
        }
        return base.distance(to: UnsafeRawPointer(found))
    }
}
