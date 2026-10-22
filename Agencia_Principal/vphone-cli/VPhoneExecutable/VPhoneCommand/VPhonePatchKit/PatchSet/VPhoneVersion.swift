// VPhoneVersion.swift — A major.minor.patch version, parsed once.
//
// One type for every version this kit compares: the iPhone base and cloudOS
// `ProductVersion` a patch is gated on, and the PatchKit API a patch set is built
// against. They are the same shape and the same comparison, so they are the same
// type — the alternative was a pair of booleans per release the pipeline cared
// about, which stopped scaling at the second one.

import Foundation

public struct VPhoneVersion: Sendable, Hashable, Comparable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int = 0, patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// Parses "27", "26.4" or "18.6.2". A missing component reads as 0, matching
    /// how Apple writes "27.0". Anything non-numeric is nil rather than zero, so a
    /// misread version never silently compares equal to a real one.
    public init?(_ text: String?) {
        guard let text, !text.isEmpty else { return nil }
        let fields = text.split(separator: ".", omittingEmptySubsequences: false)
        guard fields.count <= 3 else { return nil }
        var parsed = [0, 0, 0]
        for (index, field) in fields.enumerated() {
            guard let value = Int(field), value >= 0 else { return nil }
            parsed[index] = value
        }
        major = parsed[0]
        minor = parsed[1]
        patch = parsed[2]
    }

    /// The PatchKit API this framework is. Raised when a public symbol is added, so
    /// a set that needs the new symbol refuses to load on an older bundle.
    public static let currentPatchKit = VPhoneVersion(major: 1, minor: 0)

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    public var description: String {
        patch == 0 ? "\(major).\(minor)" : "\(major).\(minor).\(patch)"
    }
}

// MARK: - Coding

extension VPhoneVersion: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let parsed = VPhoneVersion(text) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Not a major.minor.patch version: \(text)",
            )
        }
        self = parsed
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
