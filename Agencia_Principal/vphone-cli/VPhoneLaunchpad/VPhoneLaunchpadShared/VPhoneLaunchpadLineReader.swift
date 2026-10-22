import Foundation

/// Splits a child's output into display lines. `vphone-cli` redraws progress
/// with carriage returns and colours some output, so both `\r` and `\n` end a
/// line, ANSI escape sequences are dropped, and blank lines are skipped.
///
/// A running guest's console goes through this line by line, so a chunk is
/// split in one pass: the unterminated rest is kept once at the end instead
/// of being shifted down after every line, and escape sequences are dropped
/// by a scan, not a regular expression compiled for each line.
nonisolated struct VPhoneLaunchpadLineSplitter {
    private var buffer = Data()

    mutating func feed(_ data: Data, _ onLine: (String) -> Void) {
        buffer.append(data)
        let consumed = buffer.withUnsafeBytes { raw -> Int in
            let bytes = raw.bindMemory(to: UInt8.self)
            var start = 0
            for index in bytes.indices where bytes[index] == 0x0A || bytes[index] == 0x0D {
                Self.emit(UnsafeBufferPointer(rebasing: bytes[start ..< index]), onLine)
                start = index + 1
            }
            return start
        }
        if consumed == buffer.count {
            buffer.removeAll(keepingCapacity: true)
        } else if consumed > 0 {
            buffer = Data(buffer.dropFirst(consumed))
        }
    }

    mutating func flush(_ onLine: (String) -> Void) {
        buffer.withUnsafeBytes { raw in
            Self.emit(raw.bindMemory(to: UInt8.self), onLine)
        }
        buffer.removeAll()
    }

    private static func emit(_ bytes: UnsafeBufferPointer<UInt8>, _ onLine: (String) -> Void) {
        var text = String(decoding: bytes, as: UTF8.self)
        if bytes.contains(0x1B) {
            text = strippingEscapes(text)
        }
        if !isBlank(text) {
            onLine(text)
        }
    }

    /// `text` without its CSI sequences: ESC `[`, parameter bytes `0-9 ; ?`,
    /// intermediate bytes ` -/`, then one final byte `@-~`. This removes what
    /// the pattern `\u{1B}\[[0-9;?]*[ -/]*[@-~]` matches; the three byte sets
    /// are disjoint, so a greedy scan finds the same matches. An ESC that
    /// starts no sequence stays. Only ASCII bytes go, so the rest stays valid
    /// UTF-8.
    static func strippingEscapes(_ text: String) -> String {
        let bytes = Array(text.utf8)
        var output: [UInt8] = []
        output.reserveCapacity(bytes.count)
        var index = 0
        while index < bytes.count {
            if bytes[index] == 0x1B, index + 1 < bytes.count, bytes[index + 1] == 0x5B {
                var end = index + 2
                while end < bytes.count, (0x30 ... 0x39).contains(bytes[end]) || bytes[end] == 0x3B || bytes[end] == 0x3F {
                    end += 1
                }
                while end < bytes.count, (0x20 ... 0x2F).contains(bytes[end]) {
                    end += 1
                }
                if end < bytes.count, (0x40 ... 0x7E).contains(bytes[end]) {
                    index = end + 1
                    continue
                }
            }
            output.append(bytes[index])
            index += 1
        }
        return String(decoding: output, as: UTF8.self)
    }

    /// Empty, or only tabs and space separators (Unicode category Zs): what
    /// trimming `CharacterSet.whitespaces` leaves empty.
    private static func isBlank(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy { $0 == "\t" || $0.properties.generalCategory == .spaceSeparator }
    }
}

nonisolated enum VPhoneLaunchpadLineReader {
    /// Reads `handle` until end of file on the calling thread.
    static func readLines(from handle: FileHandle, onLine: (String) -> Void) {
        var splitter = VPhoneLaunchpadLineSplitter()
        while true {
            let chunk = handle.availableData
            if chunk.isEmpty {
                break
            }
            splitter.feed(chunk, onLine)
        }
        splitter.flush(onLine)
    }
}

// MARK: - Panic lines

/// Whether a console line reports a kernel panic. Every line a running guest
/// prints is checked, so the many lines that hold neither `panic` nor
/// `ucceeded` skip the regular expression.
nonisolated enum VPhoneLaunchpadPanicLine {
    static let pattern = #"(^|[^p])(panic|kernel panic|panic\.apple\.com|stackshot succeeded)"#

    static func matches(_ line: String) -> Bool {
        // Every match holds `panic` or `succeeded` in some case. Case-
        // insensitive matching may take a long s for the s, so the check
        // looks for `ucceeded`, which only ASCII letters spell.
        guard contains(line, "panic") || contains(line, "ucceeded") else {
            return false
        }
        return line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Whether `text` holds `needle`, a lowercase ASCII word, in any ASCII
    /// case.
    static func contains(_ text: String, _ needle: StaticString) -> Bool {
        let word = UnsafeBufferPointer(start: needle.utf8Start, count: needle.utf8CodeUnitCount)
        var text = text
        return text.withUTF8 { bytes in
            var start = 0
            while start + word.count <= bytes.count {
                var offset = 0
                // Setting bit 5 lowers an ASCII capital and moves no other
                // byte onto a lowercase letter.
                while offset < word.count, bytes[start + offset] | 0x20 == word[offset] {
                    offset += 1
                }
                if offset == word.count {
                    return true
                }
                start += 1
            }
            return false
        }
    }
}
