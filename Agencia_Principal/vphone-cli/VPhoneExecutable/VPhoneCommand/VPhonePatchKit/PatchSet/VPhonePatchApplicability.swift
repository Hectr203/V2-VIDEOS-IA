// VPhonePatchApplicability.swift — The version gate a patch declares.
//
// A VM is built from two OSes: the iPhone base whose userland is restored into
// the guest, and the cloudOS whose kernel and boot chain run it. A patch may
// care about either, so the gate names both and defaults to "any".

import Foundation

public struct VPhonePatchApplicability: Sendable, Hashable, Codable {
    /// The iPhone base release whose userland ships in the guest.
    public var iOSBase: VPhoneVersionRequirement
    /// The cloudOS release supplying the kernel and boot chain.
    public var cloudOS: VPhoneVersionRequirement

    public init(
        iOSBase: VPhoneVersionRequirement = .any,
        cloudOS: VPhoneVersionRequirement = .any,
    ) {
        self.iOSBase = iOSBase
        self.cloudOS = cloudOS
    }

    /// Applies to every pairing.
    public static let always = VPhonePatchApplicability()

    /// Both requirements must hold; an unreadable version satisfies only `.any`.
    public func matches(iOSBase base: VPhoneVersion?, cloudOS cloud: VPhoneVersion?) -> Bool {
        iOSBase.matches(base) && cloudOS.matches(cloud)
    }

    private enum CodingKeys: String, CodingKey {
        case iOSBase = "IOSBase"
        case cloudOS = "CloudOS"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        iOSBase = try container.decodeIfPresent(VPhoneVersionRequirement.self, forKey: .iOSBase) ?? .any
        cloudOS = try container.decodeIfPresent(VPhoneVersionRequirement.self, forKey: .cloudOS) ?? .any
    }

    /// Only the requirements that say something are written, so an unconditional
    /// patch's plist entry stays empty rather than carrying two `Any` dicts.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if iOSBase != .any {
            try container.encode(iOSBase, forKey: .iOSBase)
        }
        if cloudOS != .any {
            try container.encode(cloudOS, forKey: .cloudOS)
        }
    }
}

extension VPhonePatchApplicability: CustomStringConvertible {
    public var description: String {
        switch (iOSBase, cloudOS) {
        case (.any, .any): "any"
        case (.any, _): "cloudOS \(cloudOS)"
        case (_, .any): "iOS \(iOSBase)"
        default: "iOS \(iOSBase), cloudOS \(cloudOS)"
        }
    }
}
