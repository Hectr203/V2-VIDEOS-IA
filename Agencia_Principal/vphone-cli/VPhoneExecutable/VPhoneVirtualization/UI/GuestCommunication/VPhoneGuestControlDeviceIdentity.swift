import Foundation

// MARK: - Profile UDID

/// The UDID libmisfix gives misagent for provisioning profile checks. Xcode,
/// devicectl and lockdown keep seeing the guest's own UDID. vphoned writes the
/// hook's settings file, reads it back and restarts misagent, so a change
/// applies to the next app install. The guest itself does not restart.
extension VPhoneGuestControl {
    /// The configured UDID, or nil when profiles are checked against the
    /// guest's own.
    func profileUDID() async throws -> String? {
        try await udidCall("udid.get")
    }

    /// Sets the UDID, or clears it when `udid` is nil. Returns the UDID the
    /// guest reports afterwards.
    @discardableResult
    func setProfileUDID(_ udid: String?) async throws -> String? {
        if let udid {
            return try await udidCall("udid.set", params: ["udid": udid])
        }
        return try await udidCall("udid.clear")
    }

    private func udidCall(_ method: String, params: [String: Any] = [:]) async throws -> String? {
        guard guestCapabilities.contains("udid_override") else {
            throw ControlError.unsupportedCapability("udid_override")
        }
        let result = try await call(method, params: params)
        return (result["udid"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    /// The UDID in the form a provisioning profile lists it, or nil when the
    /// text is not a UDID: 8 and 16 hex digits joined by a hyphen (A12 and
    /// later, listed upper-case), or 40 hex digits (earlier devices, listed
    /// lower-case). misagent compares strings, so the case is normalized.
    ///
    /// Only the menu applies this. vphoned's `udid.set` stores any non-empty
    /// string as sent, so the API and `vphone.sock` can probe unusual values.
    nonisolated static func normalizedUDID(_ value: String) -> String? {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let isHex = { (part: Substring) in part.allSatisfy { $0.isASCII && $0.isHexDigit } }
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        if parts.count == 2, parts[0].count == 8, parts[1].count == 16, parts.allSatisfy(isHex) {
            return text.uppercased()
        }
        if parts.count == 1, text.count == 40, isHex(Substring(text)) {
            return text.lowercased()
        }
        return nil
    }
}
