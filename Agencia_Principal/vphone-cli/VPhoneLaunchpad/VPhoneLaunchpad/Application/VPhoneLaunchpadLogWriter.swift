import Foundation

// MARK: - Writer

/// Appends lines to a log file on a serial queue, so command output is
/// written from the thread that read it and never waits on the main actor.
/// Lines that arrive while a write is under way go out together in the next
/// one, so a chatty command costs a write per batch, not per line. Keeps the
/// last few lines for error details.
final nonisolated class VPhoneLaunchpadLogWriter: @unchecked Sendable {
    let url: URL
    private let queue = DispatchQueue(label: "com.vphone.launchpad.log")
    private let lock = NSLock()
    private var handle: FileHandle?
    private var recent: [String] = []
    /// Bytes not yet handed to the queue, and whether a write is scheduled
    /// to take them. Both under `lock`.
    private var pending = Data()
    private var isFlushScheduled = false

    /// Starts an empty log at `url`, replacing any earlier one.
    init(url: URL) {
        self.url = url
        queue.async { [self] in
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: url.path, contents: nil)
            handle = try? FileHandle(forWritingTo: url)
        }
    }

    deinit {
        try? handle?.close()
    }

    func write(_ line: String) {
        let schedules = lock.withLock {
            recent.append(line)
            if recent.count > 12 {
                recent.removeFirst(recent.count - 12)
            }
            pending.append(contentsOf: line.utf8)
            pending.append(0x0A)
            let schedules = !isFlushScheduled
            isFlushScheduled = true
            return schedules
        }
        if schedules {
            queue.async { [self] in
                let data = lock.withLock {
                    let data = pending
                    pending = Data()
                    isFlushScheduled = false
                    return data
                }
                try? handle?.write(contentsOf: data)
            }
        }
    }

    /// The last lines written, for an error's detail text.
    var tail: String {
        lock.withLock { recent.joined(separator: "\n") }
    }
}
