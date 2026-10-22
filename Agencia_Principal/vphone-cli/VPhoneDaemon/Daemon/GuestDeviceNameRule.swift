import Foundation

// MARK: - Device Name Rule

/// The device name rule `device.name.set` enforces: the host's
/// (`VPhoneGuestDeviceName.validate`), which the guest's
/// (`VPDeviceNameCreateFromBytes`) accepts. Not blank, at most 255 UTF-8
/// bytes, no control character. SystemConfiguration takes any such string as
/// a ComputerName and derives the DNS and mDNS names from it.
///
/// Nothing here touches the guest, so `VPhoneDaemon/Tests/run-logic-tests.sh`
/// builds this file on the Mac.
enum GuestDeviceNameRule {
    static let maximumBytes = 255

    /// Why `name` is refused, nil when it is accepted.
    static func problem(_ name: String) -> String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "name must not be blank"
        }
        if name.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) {
            return "name must not contain a control character"
        }
        if name.utf8.count > maximumBytes {
            return "name must be at most \(maximumBytes) bytes in UTF-8"
        }
        return nil
    }
}
