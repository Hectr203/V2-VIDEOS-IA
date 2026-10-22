import Foundation

// MARK: - VPhoneGuestEnvironment

/// The libraries vphone keeps in the guest's /usr/lib. cfw install places them
/// on the system volume, and the environment update replaces changed ones in a
/// running guest. vphoned keeps the same list in `GuestAPI+Environment.swift`.
public enum VPhoneGuestEnvironment {
    public static let libraries = [
        "launchdhook-vphone.dylib",
        "SystemHook-vphone.dylib",
        "libvcamcaptured.dylib",
        "libcamfix.dylib",
        "libmisfix.dylib",
        "libhapticsfix.dylib",
        "libbatteryhealthfix.dylib",
        "libdevicehubfix.dylib",
        "libdevicename.dylib",
        "libprefsfix.dylib",
        "libsigninfix.dylib",
        "libvphonegyro.dylib",
        "libvphoneattitude.dylib",
    ]

    /// Selection installs/removes these. A live hash sync may replace an
    /// installed copy, but must never reinstall a patch the user turned off.
    public static let selectedLibraries: Set<String> = ["libvphonegyro.dylib", "libvphoneattitude.dylib"]
}
