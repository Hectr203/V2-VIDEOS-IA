import Foundation

// MARK: - Errors

public enum VPhoneGuestDeviceNameError: Error, Equatable {
    case empty
    case tooLong(byteCount: Int)
    case controlCharacter
}

extension VPhoneGuestDeviceNameError: CustomStringConvertible, LocalizedError {
    public var description: String {
        switch self {
        case .empty:
            "The name is blank, so it cannot be a device name."
        case let .tooLong(byteCount):
            "The name is \(byteCount) bytes long in UTF-8; a device name is at most \(VPhoneGuestDeviceName.maximumByteCount)."
        case .controlCharacter:
            "The name contains a control character such as a line break or tab, which a device name cannot."
        }
    }

    public var errorDescription: String? {
        description
    }
}

// MARK: - Device Name

/// The guest shows the VM's name as its device name: what Xcode's device list
/// and `xcrun devicectl list devices` report. vphone-vm hands it to vphoned
/// (`device.name.set`) after every connect; vphoned stores it where guest hooks
/// read it, so configd publishes it and lockdownd refuses to change it, from
/// that moment and from the start of every later boot. A VM name that cannot
/// be a device name is not handed over, and the guest keeps its own.
public enum VPhoneGuestDeviceName {
    /// The longest name accepted, in UTF-8 bytes. The guest applies the same
    /// limit (VPhoneGuestComponents/DeviceName/DeviceNamePolicy.c).
    public static let maximumByteCount = 255

    /// Throws unless `name` can be a device name: not blank, at most
    /// `maximumByteCount` UTF-8 bytes, and no control character (C0, DEL or
    /// C1). Any other character, spaces and emoji included, is allowed.
    public static func validate(_ name: String) throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw VPhoneGuestDeviceNameError.empty
        }
        // Checked before the length, so a name with a line break is reported
        // as that rather than as too long.
        if name.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) {
            throw VPhoneGuestDeviceNameError.controlCharacter
        }
        if name.utf8.count > maximumByteCount {
            throw VPhoneGuestDeviceNameError.tooLong(byteCount: name.utf8.count)
        }
    }

    public static func isValid(_ name: String) -> Bool {
        (try? validate(name)) != nil
    }
}
