// DyldSharedCacheUndoLog.swift — The original bytes behind every dyld-shared-cache edit.
//
// The shared cache is several gigabytes, so turning a cache patch back off
// cannot mean keeping a pristine copy. It means knowing, byte for byte, what
// each patch overwrote. Before a `DyldSharedCacheChunkSet` writes, it reads the
// bytes it is about to replace and appends them here, tagged with the chunk
// file and the file offset they came from. A later run that finds a patch now
// deselected writes those bytes back where they were and re-attests the pages
// they land in, which is byte-for-byte the pristine cache for that patch.
//
// What this does NOT store is the re-attestation writes themselves — the slot
// hashes `DyldSharedCacheCodeSignature` rewrites after a content edit. Those are
// derived, not chosen: the slot hash of a 16 KiB page is the SHA-256 of the
// page. Two patches can land in one page, so restoring one patch's slot bytes
// to "pristine" while the other patch stays would write the wrong hash for a
// page that is not pristine. The correct inverse is therefore: put the content
// bytes back, then re-hash whatever the page now holds. Re-attesting the
// restored page reproduces the pristine slot hash exactly when (and only when)
// the page is now pristine, and the right non-pristine hash otherwise. So the
// undo log records content writes and leaves the slot hashes to be recomputed.
//
// A record is keyed by the patch identifier that wrote it, so a revert can act
// on one patch without disturbing another's bytes. An identifier with no
// records is a patch that wrote nothing — an idempotent no-op on an
// already-patched or self-gated cache — and reverting it is likewise nothing.

import Foundation
import VPhonePatchKit

/// Every byte range a set of dyld-shared-cache patches overwrote, enough to put
/// the original bytes back for any subset of them.
public struct DyldSharedCacheUndoLog: Codable, Sendable, Hashable {
    /// One contiguous run of bytes a patch replaced, and what was there before.
    public struct Record: Codable, Sendable, Hashable {
        /// The patch declaration identifier whose write this was.
        public var patchID: String
        /// The chunk file, named relative to the cache directory
        /// (`dyld_shared_cache_arm64e`, `…​.01`, …) so the log stays valid when
        /// the cache directory is the same tree at a different absolute path.
        public var chunk: String
        /// Byte offset of the run within `chunk`.
        public var fileOffset: Int
        /// The virtual address the run starts at, for re-attestation.
        public var vma: UInt64
        /// The bytes that were there before the patch wrote. Base64 in JSON.
        public var original: Data

        public init(patchID: String, chunk: String, fileOffset: Int, vma: UInt64, original: Data) {
            self.patchID = patchID
            self.chunk = chunk
            self.fileOffset = fileOffset
            self.vma = vma
            self.original = original
        }

        private enum CodingKeys: String, CodingKey {
            case patchID = "PatchID"
            case chunk = "Chunk"
            case fileOffset = "FileOffset"
            case vma = "VMA"
            case original = "Original"
        }
    }

    public var records: [Record]

    public init(records: [Record] = []) {
        self.records = records
    }

    private enum CodingKeys: String, CodingKey {
        case records = "Records"
    }

    // MARK: - Building

    /// Append a run, assuming it has not been recorded yet. The caller — a
    /// `DyldSharedCacheChunkSet` capturing a write — supplies everything but the
    /// identifier, which `stamp(patchID:)` fills once the patch is known.
    public mutating func capture(chunk: String, fileOffset: Int, vma: UInt64, original: Data) {
        records.append(Record(patchID: "", chunk: chunk, fileOffset: fileOffset, vma: vma, original: original))
    }

    /// Give every still-unstamped record this patch identifier. Called once per
    /// patcher invocation, because one invocation applies one declared patch.
    public mutating func stamp(patchID: String) {
        for index in records.indices where records[index].patchID.isEmpty {
            records[index].patchID = patchID
        }
    }

    /// The identifiers that have at least one recorded run.
    public var patchIDs: Set<String> {
        Set(records.map(\.patchID))
    }

    /// Fold `other`'s records in after this log's. A patch identifier present in
    /// both keeps both sides' runs; de-duplication is not needed because each
    /// run is a distinct (chunk, offset) a patch wrote exactly once per install.
    public mutating func merge(_ other: DyldSharedCacheUndoLog) {
        records.append(contentsOf: other.records)
    }

    /// The log to store after a patch run for `patchID` captured `captured`, or
    /// nil when the stored log should be left exactly as it is.
    ///
    /// Nothing captured — an idempotent re-run over sites that already carry
    /// the patch, a self-gated no-op, or a dry run — returns nil, so the
    /// originals an earlier run recorded for the patch are kept. Without that a
    /// second install would forget how to revert every patch it found already
    /// applied.
    ///
    /// Something captured is merged in, not swapped in: a run can find some
    /// sites of a patch already written and write the rest, and only the new
    /// sites are captured. A record for a (chunk, offset) the log already has
    /// keeps the older original, which is the byte that was there before any
    /// run touched it.
    public static func updated(
        existing: DyldSharedCacheUndoLog?,
        captured: DyldSharedCacheUndoLog,
        patchID: String,
    ) -> DyldSharedCacheUndoLog? {
        var fresh = captured
        fresh.stamp(patchID: patchID)
        guard !fresh.records.isEmpty else { return nil }
        var merged = existing ?? DyldSharedCacheUndoLog()
        let known = Set(merged.records.map { "\($0.chunk)@\($0.fileOffset)" })
        merged.records.append(contentsOf: fresh.records.filter { !known.contains("\($0.chunk)@\($0.fileOffset)") })
        return merged
    }

    /// Check every record against the cache in `directory` before anything is
    /// written: a plain chunk name, a regular file that is not a link, a
    /// non-negative offset, and a run that ends inside the file. One bad record
    /// refuses the whole log — a log that does not describe this cache must not
    /// half-revert it.
    public func validate(in directory: URL, patchIDs: Set<String>? = nil) throws {
        var sizes: [String: Int] = [:]
        for record in records where patchIDs?.contains(record.patchID) ?? true {
            guard !record.chunk.isEmpty, !record.chunk.contains("/"), record.chunk != ".", record.chunk != ".."
            else {
                throw DyldSharedCacheError.undoChunkOutsideCache(chunk: record.chunk)
            }
            let size: Int
            if let known = sizes[record.chunk] {
                size = known
            } else {
                var metadata = stat()
                let path = directory.appendingPathComponent(record.chunk).path
                guard lstat(path, &metadata) == 0, metadata.st_mode & S_IFMT == S_IFREG else {
                    throw DyldSharedCacheError.undoRecordInvalid(chunk: record.chunk, reason: "not a regular file beside the cache")
                }
                size = Int(metadata.st_size)
                sizes[record.chunk] = size
            }
            guard record.fileOffset >= 0, !record.original.isEmpty,
                  record.fileOffset <= size, record.original.count <= size - record.fileOffset
            else {
                throw DyldSharedCacheError.undoRecordInvalid(
                    chunk: record.chunk,
                    reason: "offset \(record.fileOffset) + \(record.original.count) bytes is outside the file (\(size) bytes)",
                )
            }
        }
    }

    /// This log without any record belonging to `patchIDs` — what remains after
    /// those patches are reverted and their runs no longer describe the cache.
    public func removing(patchIDs: Set<String>) -> DyldSharedCacheUndoLog {
        DyldSharedCacheUndoLog(records: records.filter { !patchIDs.contains($0.patchID) })
    }

    /// The records belonging to any of `patchIDs`, newest write last so that a
    /// restore replays them in reverse and the earliest original wins when two
    /// runs of one patch overlap (they do not today, but order makes it safe).
    public func records(forPatchIDs patchIDs: Set<String>) -> [Record] {
        records.filter { patchIDs.contains($0.patchID) }
    }

    // MARK: - Serialisation

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> DyldSharedCacheUndoLog {
        try JSONDecoder().decode(DyldSharedCacheUndoLog.self, from: data)
    }

    // MARK: - Restoring

    /// Put the original bytes of `patchIDs` back into the chunk files under
    /// `directory`, in reverse record order so an earlier write wins any
    /// overlap. The caller re-attests the touched pages afterwards; the returned
    /// spans are exactly what to re-attest, one per restored run.
    ///
    /// A record naming a chunk that is not under `directory` is refused rather
    /// than written through a path that escaped the cache — the log is trusted
    /// only to describe the cache it sits beside.
    @discardableResult
    public func restore(
        patchIDs: Set<String>,
        in directory: URL,
        log: ((String) -> Void)? = nil,
    ) throws -> [DyldSharedCacheWriteSpan] {
        try validate(in: directory, patchIDs: patchIDs)
        var spans: [DyldSharedCacheWriteSpan] = []
        for record in records(forPatchIDs: patchIDs).reversed() {
            let url = directory.appendingPathComponent(record.chunk)
            let handle = try FileHandle(forUpdating: url)
            defer { try? handle.close() }
            try handle.seek(toOffset: UInt64(record.fileOffset))
            try handle.write(contentsOf: record.original)
            spans.append(DyldSharedCacheWriteSpan(vma: record.vma, length: record.original.count))
            log?("      [+] revert: \(record.original.count) byte(s) at 0x"
                + String(record.vma, radix: 16, uppercase: true) + " in \(record.chunk) (\(record.patchID))")
        }
        return spans
    }
}

// MARK: - Earlier implementations

public extension DyldSharedCacheUndoLog {
    /// Patches whose implementation changed under the same identifier, and how
    /// a record written by an earlier one looks. A guest receipt only names the
    /// identifier, so without this an installed guest would keep the old bytes
    /// for good; `cfw install` and the environment update use it to revert the
    /// old records and apply the current implementation in the same run.
    ///
    /// `dyld-boot-iomfb_force_kern` first rewrote each swap trampoline's first
    /// instruction, one 4-byte record per entry point. It now writes a 16-byte
    /// conditional dispatcher per entry point, so a 4-byte record is the
    /// unconditional version, which leaves DeviceHub's capture display black.
    static let outdatedImplementations: [String: @Sendable (Record) -> Bool] = [
        "dyld-boot-iomfb_force_kern": { $0.original.count == 4 },
    ]

    /// Whether any record of `patchID` was written by an earlier
    /// implementation. False for a patch with no records, which cannot be
    /// reverted from this log anyway.
    func hasOutdatedImplementation(of patchID: String) -> Bool {
        guard let outdated = Self.outdatedImplementations[patchID] else { return false }
        return records(forPatchIDs: [patchID]).contains(where: outdated)
    }
}
