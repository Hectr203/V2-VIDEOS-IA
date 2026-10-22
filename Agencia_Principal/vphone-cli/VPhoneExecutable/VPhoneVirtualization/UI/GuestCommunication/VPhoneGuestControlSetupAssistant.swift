import Foundation

// MARK: - Setup Assistant

/// Skipping Setup Assistant on a guest that is already activated. vphoned
/// marks setup finished for the guest's iOS version and restarts
/// SpringBoard, which then starts at the Lock Screen instead of Setup.
/// `isSetupAssistantPending` follows on the next health probe.
extension VPhoneGuestControl {
    func skipSetupAssistant() async throws {
        guard guestCapabilities.contains("setup_skip") else {
            throw ControlError.unsupportedCapability("setup_skip")
        }
        _ = try await call("setup.skip", params: ["force": true])
    }
}
