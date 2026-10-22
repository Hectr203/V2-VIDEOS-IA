// VPhoneVersionRequirement.swift — Structured OS-version conditions.
//
// A patch declares which OS releases it applies to. The condition is an enum,
// not a string like ">=27.0 <28.0": a manifest that cannot express a range it
// did not mean cannot silently widen, and a typo is a decode error rather than
// a patch that quietly matches everything.
//
// The plist form carries a `Kind` discriminator so a future case is a decode
// error in an old PatchKit instead of a misread condition.

import Foundation

public enum VPhoneVersionRequirement: Sendable, Hashable {
    /// Matches every version, including an unknown one.
    case any
    /// Matches any release of one major version, e.g. every 27.x.
    case major(Int)
    /// Matches exactly one major.minor release.
    case release(major: Int, minor: Int)
    /// Matches that release and everything after it.
    case atLeast(major: Int, minor: Int)
    /// Matches when any nested requirement matches.
    case oneOf([VPhoneVersionRequirement])
}

// MARK: - Matching

public extension VPhoneVersionRequirement {
    /// Whether `version` satisfies the requirement.
    ///
    /// A version the pipeline could not read satisfies only ``any``: a patch gated
    /// on a release must not apply when nothing knows which release this is.
    ///
    /// Only major and minor are compared. A gate names a release, not a point
    /// update, so 18.6.2 satisfies `.major(18)` and `.atLeast(18, 6)` alike.
    func matches(_ version: VPhoneVersion?) -> Bool {
        if case .any = self {
            return true
        }
        guard let version else { return false }
        switch self {
        case .any:
            return true
        case let .major(value):
            return version.major == value
        case let .release(requiredMajor, requiredMinor):
            return version.major == requiredMajor && version.minor == requiredMinor
        case let .atLeast(requiredMajor, requiredMinor):
            return (version.major, version.minor) >= (requiredMajor, requiredMinor)
        case let .oneOf(options):
            return options.contains { $0.matches(version) }
        }
    }
}

// MARK: - Plist Coding

extension VPhoneVersionRequirement: Codable {
    private enum Kind: String, Codable {
        case any = "Any"
        case major = "Major"
        case release = "Release"
        case atLeast = "AtLeast"
        case oneOf = "OneOf"
    }

    private enum CodingKeys: String, CodingKey {
        case kind = "Kind"
        case major = "Major"
        case minor = "Minor"
        case options = "Options"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .any:
            self = .any
        case .major:
            self = try .major(container.decode(Int.self, forKey: .major))
        case .release:
            self = try .release(
                major: container.decode(Int.self, forKey: .major),
                minor: container.decode(Int.self, forKey: .minor),
            )
        case .atLeast:
            self = try .atLeast(
                major: container.decode(Int.self, forKey: .major),
                minor: container.decode(Int.self, forKey: .minor),
            )
        case .oneOf:
            let options = try container.decode([VPhoneVersionRequirement].self, forKey: .options)
            guard !options.isEmpty else {
                throw DecodingError.dataCorruptedError(
                    forKey: .options,
                    in: container,
                    debugDescription: "OneOf needs at least one option; an empty list matches nothing",
                )
            }
            self = .oneOf(options)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .any:
            try container.encode(Kind.any, forKey: .kind)
        case let .major(value):
            try container.encode(Kind.major, forKey: .kind)
            try container.encode(value, forKey: .major)
        case let .release(major, minor):
            try container.encode(Kind.release, forKey: .kind)
            try container.encode(major, forKey: .major)
            try container.encode(minor, forKey: .minor)
        case let .atLeast(major, minor):
            try container.encode(Kind.atLeast, forKey: .kind)
            try container.encode(major, forKey: .major)
            try container.encode(minor, forKey: .minor)
        case let .oneOf(options):
            try container.encode(Kind.oneOf, forKey: .kind)
            try container.encode(options, forKey: .options)
        }
    }
}

// MARK: - Description

extension VPhoneVersionRequirement: CustomStringConvertible {
    public var description: String {
        switch self {
        case .any: "any"
        case let .major(value): "\(value).x"
        case let .release(major, minor): "\(major).\(minor)"
        case let .atLeast(major, minor): "\(major).\(minor)+"
        case let .oneOf(options): options.map(\.description).joined(separator: " | ")
        }
    }
}
