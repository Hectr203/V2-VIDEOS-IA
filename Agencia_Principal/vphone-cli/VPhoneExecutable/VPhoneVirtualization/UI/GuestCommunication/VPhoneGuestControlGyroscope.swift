import CoreFoundation
import Foundation

// MARK: - Gyroscope RPC

extension VPhoneGuestControl {
    func readGyroscope() async throws -> VPhoneMotionReply {
        guard guestCapabilities.contains("motion_gyroscope_toggle") else {
            throw ControlError.unsupportedCapability("motion_gyroscope_toggle")
        }
        let result = try await call("motion.gyroscope.get")
        return try gyroscopeReply(result)
    }

    func setGyroscope(_ value: VPhoneMotionConfiguration) async throws -> VPhoneMotionReply {
        guard guestCapabilities.contains("motion_gyroscope_toggle") else {
            throw ControlError.unsupportedCapability("motion_gyroscope_toggle")
        }
        let result = try await call("motion.gyroscope.set", params: [
            "enabled": value.enabled, "x": value.x, "y": value.y, "z": value.z,
        ])
        return try gyroscopeReply(result)
    }

    private func gyroscopeReply(_ result: [String: Any]) throws -> VPhoneMotionReply {
        guard let enabled = result["enabled"] as? NSNumber,
              CFGetTypeID(enabled) == CFBooleanGetTypeID(),
              let x = result["x"] as? NSNumber, let y = result["y"] as? NSNumber, let z = result["z"] as? NSNumber,
              [x, y, z].allSatisfy({
                  CFGetTypeID($0) != CFBooleanGetTypeID() && $0.doubleValue.isFinite && abs($0.doubleValue) <= 1000
              })
        else { throw ControlError.protocolError("invalid gyroscope configuration") }
        return VPhoneMotionReply(
            configuration: VPhoneMotionConfiguration(enabled: enabled.boolValue, x: x.doubleValue, y: y.doubleValue, z: z.doubleValue),
            providerRunning: result.bool("provider_running") ?? false,
        )
    }
}
