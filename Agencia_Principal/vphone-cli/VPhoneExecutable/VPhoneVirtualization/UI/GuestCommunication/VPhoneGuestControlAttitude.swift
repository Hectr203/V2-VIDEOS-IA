import CoreFoundation
import Foundation

// MARK: - Attitude RPC

extension VPhoneGuestControl {
    func readAttitude() async throws -> VPhoneMotionReply {
        guard guestCapabilities.contains("motion_attitude") else {
            throw ControlError.unsupportedCapability("motion_attitude")
        }
        return try await attitudeReply(call("motion.attitude.get"))
    }

    func setAttitude(_ value: VPhoneMotionConfiguration) async throws -> VPhoneMotionReply {
        guard guestCapabilities.contains("motion_attitude") else {
            throw ControlError.unsupportedCapability("motion_attitude")
        }
        return try await attitudeReply(call("motion.attitude.set", params: [
            "enabled": value.enabled, "roll": value.x, "pitch": value.y, "yaw": value.z,
        ]))
    }

    private func attitudeReply(_ result: [String: Any]) throws -> VPhoneMotionReply {
        guard let enabled = result["enabled"] as? NSNumber, CFGetTypeID(enabled) == CFBooleanGetTypeID(),
              let roll = result["roll"] as? NSNumber, let pitch = result["pitch"] as? NSNumber,
              let yaw = result["yaw"] as? NSNumber,
              [roll, pitch, yaw].allSatisfy({ CFGetTypeID($0) != CFBooleanGetTypeID() && $0.doubleValue.isFinite }),
              abs(roll.doubleValue) <= 180, abs(pitch.doubleValue) <= 90, abs(yaw.doubleValue) <= 180
        else { throw ControlError.protocolError("invalid attitude configuration") }
        return VPhoneMotionReply(
            configuration: VPhoneMotionConfiguration(enabled: enabled.boolValue, x: roll.doubleValue, y: pitch.doubleValue, z: yaw.doubleValue),
            providerRunning: result.bool("provider_installed") ?? false,
        )
    }
}
