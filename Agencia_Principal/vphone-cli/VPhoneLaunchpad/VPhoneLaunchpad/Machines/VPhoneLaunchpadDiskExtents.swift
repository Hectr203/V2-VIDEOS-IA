import Darwin
import Foundation

// MARK: - Physical extents

/// Where a file's data lies on its device, as `fcntl(F_LOG2PHYS_EXT)`
/// reports it: sorted, disjoint, half-open byte ranges of device offsets.
///
/// Two files share a block exactly when their ranges overlap, which is how
/// APFS clones (a machine and its template, two clones of one template)
/// are told apart from blocks a file holds alone. Unlike APFS's private size
/// (`ATTR_CMNEXT_PRIVATESIZE`), a Time Machine local snapshot does not make
/// a file's blocks look shared: only the files compared count.
nonisolated struct VPhoneLaunchpadDiskExtents: Hashable, Sendable {
    struct Range: Hashable, Sendable {
        var start: Int64
        var end: Int64

        var length: Int64 {
            end - start
        }
    }

    /// The device the offsets are on. Ranges on different devices never
    /// overlap, whatever their numbers.
    var device: Int64
    private(set) var ranges: [Range]

    init(device: Int64, ranges: [Range]) {
        self.device = device
        self.ranges = Self.normalized(ranges)
    }

    var bytes: Int64 {
        ranges.reduce(0) { $0 + $1.length }
    }

    /// Sorted, with overlapping and touching ranges merged and empty ones
    /// dropped.
    static func normalized(_ ranges: [Range]) -> [Range] {
        var merged: [Range] = []
        merged.reserveCapacity(ranges.count)
        for range in ranges.sorted(by: { $0.start < $1.start }) where range.end > range.start {
            if let last = merged.last, range.start <= last.end {
                merged[merged.count - 1].end = max(last.end, range.end)
            } else {
                merged.append(range)
            }
        }
        return merged
    }

    /// For each owner, the bytes no other owner covers. An owner is a set of
    /// files (a machine folder): blocks shared among its own files count
    /// once and are still its own.
    static func exclusiveBytes(of owners: [[Self]]) -> [Int64] {
        var exclusive = [Int64](repeating: 0, count: owners.count)
        var byDevice: [Int64: [(owner: Int, ranges: [Range])]] = [:]
        for (owner, files) in owners.enumerated() {
            var perDevice: [Int64: [Range]] = [:]
            for file in files {
                perDevice[file.device, default: []] += file.ranges
            }
            for (device, ranges) in perDevice {
                byDevice[device, default: []].append((owner, normalized(ranges)))
            }
        }
        for owners in byDevice.values {
            // A sweep over every range's ends: a stretch covered by exactly
            // one owner is that owner's. Each owner's ranges are disjoint,
            // so it is counted at most once at any offset, and the sum of
            // the covering owners names the owner when only one covers it.
            var events: [(offset: Int64, owner: Int, delta: Int)] = []
            events.reserveCapacity(owners.reduce(0) { $0 + $1.ranges.count } * 2)
            for (owner, ranges) in owners {
                for range in ranges {
                    events.append((range.start, owner, 1))
                    events.append((range.end, owner, -1))
                }
            }
            events.sort { $0.offset < $1.offset }
            var covering = 0
            var ownerSum = 0
            var previous: Int64 = 0
            for event in events {
                if covering == 1 {
                    exclusive[ownerSum] += event.offset - previous
                }
                covering += event.delta
                ownerSum += event.delta * event.owner
                previous = event.offset
            }
        }
        return exclusive
    }

    // MARK: Reading

    enum MapError: Error, Equatable {
        /// The file system does not map this file (not a regular file, a
        /// compressed file, a volume without block maps).
        case unsupported
        /// More ranges than `rangeLimit`, or past the deadline.
        case tooLarge
    }

    /// The file's data ranges. Holes are skipped with `SEEK_DATA`, so a
    /// sparse disk image costs its written extents, not its size.
    ///
    /// The descriptor is `O_EVTONLY` and held only while mapping, but it is
    /// an open descriptor: `lsof` lists this process for the file meanwhile.
    static func map(_ path: String, rangeLimit: Int = 4_000_000, deadline: ContinuousClock.Instant? = nil) -> Result<Self, MapError> {
        let descriptor = open(path, O_EVTONLY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else {
            return .failure(.unsupported)
        }
        defer { close(descriptor) }
        var status = stat()
        var volume = statfs()
        guard fstat(descriptor, &status) == 0, status.st_mode & S_IFMT == S_IFREG,
              fstatfs(descriptor, &volume) == 0
        else {
            return .failure(.unsupported)
        }
        // Whole file system blocks: the last one is allocated in full even
        // when the file ends inside it.
        let block = Int64(max(volume.f_bsize, 512))
        var ranges: [Range] = []
        var offset: off_t = 0
        while offset < status.st_size {
            let data = lseek(descriptor, offset, SEEK_DATA)
            if data < 0 {
                // ENXIO: no data past `offset`.
                if errno == ENXIO {
                    break
                }
                return .failure(.unsupported)
            }
            var hole = lseek(descriptor, data, SEEK_HOLE)
            if hole < 0 {
                hole = status.st_size
            }
            var position = data
            while position < hole {
                var request = log2phys()
                request.l2p_devoffset = position
                request.l2p_contigbytes = hole - position
                guard fcntl(descriptor, F_LOG2PHYS_EXT, &request) == 0, request.l2p_contigbytes > 0 else {
                    return .failure(.unsupported)
                }
                let run = min(request.l2p_contigbytes, hole - position)
                if request.l2p_devoffset >= 0 {
                    let start = request.l2p_devoffset / block * block
                    let end = (request.l2p_devoffset + run + block - 1) / block * block
                    if let last = ranges.last, last.end == start {
                        ranges[ranges.count - 1].end = end
                    } else {
                        ranges.append(Range(start: start, end: end))
                        if ranges.count > rangeLimit {
                            return .failure(.tooLarge)
                        }
                    }
                }
                position += run
            }
            if let deadline, ContinuousClock.now > deadline {
                return .failure(.tooLarge)
            }
            offset = hole
        }
        return .success(Self(device: Int64(status.st_dev), ranges: ranges))
    }
}
