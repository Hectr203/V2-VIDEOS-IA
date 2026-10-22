import Foundation

/// The path a running guest's console takes through Launchpad: the line
/// splitter and panic check on the `vm launch` tail, the newline translation
/// the log terminal is fed through, and the log writer. Each is checked
/// against the implementation it replaced, over logs cut at random points.
@main
struct ConsoleOutputTests {
    static func expect(_ condition: Bool, _ message: @autoclosure () -> String, line: Int = #line) {
        precondition(condition, "line \(line): \(message())")
    }

    static func main() {
        splitter()
        panicLines()
        newlines()
        writer()
        print("Console output tests passed: line splitting, panic lines, newline translation, log writer")
    }

    // MARK: - Samples

    /// A console log as a guest prints it: plain lines, coloured lines,
    /// bare and doubled line ends, progress redraws, blank lines and a little
    /// invalid UTF-8.
    static func consoleSample(lines: Int, seed: UInt64) -> Data {
        var random = SplitMix(seed: seed)
        let pieces: [String] = [
            "set_dir_stats:3204: disk1s7 setting dir-stats for ino 1234 parent 2",
            "\u{1B}[32m[vphoned]\u{1B}[0m ping ok",
            "\u{1B}[1;31mpanic(cpu 0 caller 0xfffffff0): \u{1B}[0m",
            "progress 12 100\r",
            "   \t ",
            "",
            "$ vphone-cli restore ios27-rc",
            "warning: low space",
            "\u{1B}[?25l\u{1B}[2K redraw\u{1B}[",
            "\u{1B}x not a sequence \u{1B}[12;",
            "Stackshot succeeded",
            "spanic? ppanic unpanic",
            "研究 \u{3000} ok",
        ]
        var data = Data()
        for _ in 0 ..< lines {
            data.append(contentsOf: pieces[Int(random.next() % UInt64(pieces.count))].utf8)
            switch random.next() % 10 {
            case 0: data.append(contentsOf: [0x0D, 0x0A])
            case 1: data.append(0x0D)
            case 2: data.append(contentsOf: [0xE2, 0x9C])
            default: data.append(0x0A)
            }
        }
        return data
    }

    /// `data` cut at random points, some cuts inside a line, a CR LF pair or
    /// a UTF-8 sequence.
    static func chunks(of data: Data, seed: UInt64) -> [Data] {
        var random = SplitMix(seed: seed)
        var result: [Data] = []
        var start = data.startIndex
        while start < data.endIndex {
            let length = 1 + Int(random.next() % 300)
            let end = min(start + length, data.endIndex)
            result.append(Data(data[start ..< end]))
            start = end
        }
        return result
    }

    struct SplitMix {
        var state: UInt64
        init(seed: UInt64) {
            state = seed
        }

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    // MARK: - Line splitter

    /// The splitter before it worked a chunk at a time.
    struct ReferenceSplitter {
        var buffer = Data()

        mutating func feed(_ data: Data, _ onLine: (String) -> Void) {
            buffer.append(data)
            while let end = buffer.firstIndex(where: { $0 == 0x0A || $0 == 0x0D }) {
                Self.emit(buffer[buffer.startIndex ..< end], onLine)
                buffer.removeSubrange(buffer.startIndex ... end)
            }
        }

        mutating func flush(_ onLine: (String) -> Void) {
            Self.emit(buffer, onLine)
            buffer.removeAll()
        }

        static func emit(_ bytes: Data, _ onLine: (String) -> Void) {
            let text = String(decoding: bytes, as: UTF8.self)
                .replacingOccurrences(of: "\u{1B}\\[[0-9;?]*[ -/]*[@-~]", with: "", options: .regularExpression)
            if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                onLine(text)
            }
        }
    }

    /// The splitter gives the lines the regular-expression splitter it
    /// replaced gave, wherever the reads cut the output.
    static func splitter() {
        for seed in UInt64(1) ... 6 {
            let log = consoleSample(lines: 3000, seed: seed)
            var expected: [String] = []
            var reference = ReferenceSplitter()
            reference.feed(log) { expected.append($0) }
            reference.flush { expected.append($0) }

            var splitter = VPhoneLaunchpadLineSplitter()
            var lines: [String] = []
            for part in chunks(of: log, seed: seed &* 17) {
                splitter.feed(part) { lines.append($0) }
            }
            splitter.flush { lines.append($0) }
            expect(lines == expected, "seed \(seed): \(lines.count) lines, expected \(expected.count)")

            var whole = VPhoneLaunchpadLineSplitter()
            var wholeLines: [String] = []
            whole.feed(log) { wholeLines.append($0) }
            whole.flush { wholeLines.append($0) }
            expect(wholeLines == expected, "seed \(seed) in one read")
        }

        var splitter = VPhoneLaunchpadLineSplitter()
        var lines: [String] = []
        splitter.feed(Data("\u{1B}[1;32mok\u{1B}[0m\r\n \u{2003}\t\nrest".utf8)) { lines.append($0) }
        expect(lines == ["ok"], "colour dropped, blank lines skipped: \(lines)")
        splitter.feed(Data(" of it".utf8)) { lines.append($0) }
        splitter.flush { lines.append($0) }
        expect(lines == ["ok", "rest of it"], "partial line across chunks: \(lines)")
        expect(VPhoneLaunchpadLineSplitter.strippingEscapes("a\u{1B}[b\u{1B}") == "a\u{1B}",
               "ESC [ with no parameters ends at its final byte; a trailing ESC stays")
        expect(VPhoneLaunchpadLineSplitter.strippingEscapes("a\u{1B}[12;\u{1B}[0m研") == "a\u{1B}[12;研",
               "an unfinished sequence stays")
    }

    // MARK: - Panic lines

    /// The panic check agrees with the pattern on its own, which is what
    /// `VPhoneLaunchpadCreationPipeline.isPanic` evaluated for every line.
    static func panicLines() {
        func reference(_ line: String) -> Bool {
            line.range(of: VPhoneLaunchpadPanicLine.pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
        expect(VPhoneLaunchpadPanicLine.pattern == #"(^|[^p])(panic|kernel panic|panic\.apple\.com|stackshot succeeded)"#,
               "the pattern is unchanged")
        let lines = [
            "panic(cpu 0 caller 0xfffffff0)", "Kernel Panic", "PANIC", "xnu: kernel panic", "https://panic.apple.com/",
            "spanic", "ppanic", "PPANIC", "Ppanic", "unpanic", "stackshot succeeded", "Stackshot SUCCEEDED",
            "ſtackshot ſucceeded", "pstackshot succeeded", "stackshot  succeeded", "pani c", "set_dir_stats:3204: disk1s7",
            "", "p", "panic", "\u{1B}[31mpanic\u{1B}[0m", "研究panic",
        ]
        for line in lines {
            let expected = reference(line)
            expect(VPhoneLaunchpadPanicLine.matches(line) == expected, "\(line.debugDescription) should be \(expected)")
        }
        for seed in UInt64(1) ... 3 {
            var splitter = VPhoneLaunchpadLineSplitter()
            var count = 0
            splitter.feed(consoleSample(lines: 3000, seed: seed)) { line in
                expect(VPhoneLaunchpadPanicLine.matches(line) == reference(line), "\(line.debugDescription), seed \(seed)")
                count += 1
            }
            expect(count > 0, "seed \(seed) gave lines")
        }
        expect(VPhoneLaunchpadPanicLine.contains("xPaNiC", "panic"), "any ASCII case")
        expect(!VPhoneLaunchpadPanicLine.contains("pan", "panic"), "shorter than the word")
        expect(!VPhoneLaunchpadPanicLine.contains("p@nic", "panic"), "only letters fold")
    }

    // MARK: - Newline translation

    /// The translation before it copied runs between line feeds.
    struct ReferenceNewlineTranslator {
        var previous: UInt8 = 0

        mutating func translate(_ data: Data) -> Data {
            var output = Data()
            for byte in data {
                if byte == 0x0A, previous != 0x0D {
                    output.append(0x0D)
                }
                output.append(byte)
                previous = byte
            }
            return output
        }
    }

    /// The translator's output does not depend on where the reads cut the
    /// log, and matches the byte-at-a-time translation it replaced.
    static func newlines() {
        for seed in UInt64(1) ... 6 {
            let log = consoleSample(lines: 3000, seed: seed)
            let parts = chunks(of: log, seed: seed &* 31)
            var reference = ReferenceNewlineTranslator()
            let expected = parts.reduce(into: Data()) { $0.append(reference.translate($1)) }
            var whole = VPhoneLaunchpadNewlineTranslator()
            var cut = VPhoneLaunchpadNewlineTranslator()
            let joined = parts.reduce(into: Data()) { $0.append(cut.translate($1)) }
            expect(whole.translate(log) == expected, "whole, seed \(seed)")
            expect(joined == expected, "chunked, seed \(seed)")
        }
        var newline = VPhoneLaunchpadNewlineTranslator()
        expect(newline.translate(Data()).isEmpty, "empty chunk")
        expect(newline.translate(Data("a\r".utf8)) == Data("a\r".utf8), "CR at a chunk's end")
        expect(newline.translate(Data("\nb\n".utf8)) == Data("\nb\r\n".utf8), "its LF gains nothing")
        expect(newline.translate(Data("\n\n".utf8)) == Data("\r\n\r\n".utf8), "empty lines")
        // The log tail hands over a slice once it has skipped a partial line.
        let chunk = Data("partial\nx\ny".utf8)
        let slice = chunk[chunk.index(after: chunk.firstIndex(of: 0x0A)!)...]
        var sliced = VPhoneLaunchpadNewlineTranslator()
        expect(sliced.translate(slice) == Data("x\r\ny".utf8), "a slice that does not start at zero")
    }

    // MARK: - Log writer

    /// The writer keeps every line, in order, however many arrive at once,
    /// and the last twelve for error details.
    static func writer() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("console-output-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("create.log")
        let writer = VPhoneLaunchpadLogWriter(url: url)
        let count = 20000
        DispatchQueue.concurrentPerform(iterations: 4) { worker in
            for index in 0 ..< count / 4 {
                writer.write("\(worker) \(index)")
            }
        }
        var text = ""
        for _ in 0 ..< 500 {
            text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            if text.split(separator: "\n").count == count {
                break
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
        let lines = text.split(separator: "\n")
        expect(lines.count == count, "\(lines.count) of \(count) lines written")
        expect(text.hasSuffix("\n"), "every line ends with a line feed")
        for worker in 0 ..< 4 {
            let own = lines.filter { $0.hasPrefix("\(worker) ") }.map { Int($0.split(separator: " ")[1])! }
            expect(own == Array(0 ..< count / 4), "worker \(worker)'s lines in order")
        }
        expect(writer.tail.split(separator: "\n").count == 12, "tail keeps twelve lines")
    }
}
