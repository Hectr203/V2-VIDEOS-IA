// VPhonePatchSelection.swift — Which declared patches a preset turns on.
//
// The selection is either an allow list or a block list, never both: the two
// read the same in a plist but mean opposite things for a patch nobody named,
// and a manifest able to carry both invites a preset where one list silently
// wins. Making them separate cases removes the question.

import Foundation

public enum VPhonePatchSelection: Sendable, Hashable {
    /// Every declared patch whose version gate matches.
    case all
    /// Only these patch identifiers. A patch nobody named is off.
    case allow(Set<String>)
    /// Everything except these identifiers. A patch nobody named is on.
    case block(Set<String>)
}

public extension VPhonePatchSelection {
    /// Whether the selection names this patch as enabled, before the version
    /// gate is consulted.
    func includes(_ identifier: String) -> Bool {
        switch self {
        case .all: true
        case let .allow(identifiers): identifiers.contains(identifier)
        case let .block(identifiers): !identifiers.contains(identifier)
        }
    }

    /// The identifiers the selection names, whichever way it names them.
    /// The resolver checks these against the declared patches so a typo is an
    /// error rather than an allow list that turns nothing on.
    var namedIdentifiers: Set<String> {
        switch self {
        case .all: []
        case let .allow(identifiers), let .block(identifiers): identifiers
        }
    }

    /// The same selection with `identifiers` additionally turned off.
    ///
    /// Half of how a VM's own checkmarks compose with a preset: unchecking a patch
    /// narrows an allow list and widens a block list.
    func blocking(_ identifiers: Set<String>) -> VPhonePatchSelection {
        guard !identifiers.isEmpty else { return self }
        switch self {
        case .all:
            return .block(identifiers)
        case let .allow(allowed):
            return .allow(allowed.subtracting(identifiers))
        case let .block(blocked):
            return .block(blocked.union(identifiers))
        }
    }

    /// The same selection with `identifiers` additionally turned on.
    ///
    /// The other half: checking a patch the preset left out widens an allow list
    /// and narrows a block list. It changes only the selection — a patch whose
    /// version gate rules it out here still does not apply, so checking a box can
    /// never put a patch somewhere it was never meant to run.
    func allowing(_ identifiers: Set<String>) -> VPhonePatchSelection {
        guard !identifiers.isEmpty else { return self }
        switch self {
        case .all:
            return .all
        case let .allow(allowed):
            return .allow(allowed.union(identifiers))
        case let .block(blocked):
            return .block(blocked.subtracting(identifiers))
        }
    }
}

// MARK: - Plist Coding

extension VPhonePatchSelection: Codable {
    private enum Kind: String, Codable {
        case all = "All"
        case allow = "Allow"
        case block = "Block"
    }

    private enum CodingKeys: String, CodingKey {
        case kind = "Kind"
        case patches = "Patches"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .all:
            self = .all
        case .allow:
            self = try .allow(Set(container.decode([String].self, forKey: .patches)))
        case .block:
            self = try .block(Set(container.decode([String].self, forKey: .patches)))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .all:
            try container.encode(Kind.all, forKey: .kind)
        case let .allow(identifiers):
            try container.encode(Kind.allow, forKey: .kind)
            try container.encode(identifiers.sorted(), forKey: .patches)
        case let .block(identifiers):
            try container.encode(Kind.block, forKey: .kind)
            try container.encode(identifiers.sorted(), forKey: .patches)
        }
    }
}

extension VPhonePatchSelection: CustomStringConvertible {
    public var description: String {
        switch self {
        case .all: "all patches"
        case let .allow(identifiers): "only \(identifiers.count) patch(es)"
        case let .block(identifiers): "all but \(identifiers.count) patch(es)"
        }
    }
}
