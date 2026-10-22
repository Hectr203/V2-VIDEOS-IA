import CoreFoundation
import Foundation
import VphonedNative

// MARK: - Device Attitude

extension GuestAPI {
    private static let attitudeLock = NSLock()

    static func executeAttitude(_ method: String, _ params: [String: Any]) throws -> [String: Any]? {
        guard ["motion.attitude.get", "motion.attitude.set", "motion.attitude.clear"].contains(method) else { return nil }
        attitudeLock.lock()
        defer { attitudeLock.unlock() }
        if method != "motion.attitude.get" {
            var angles = [Double](repeating: 0, count: 3)
            var enabled = method == "motion.attitude.set"
            if method == "motion.attitude.set" {
                if let flag = params["enabled"] {
                    guard let number = flag as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else {
                        throw GuestAPIError.invalidRequest("enabled must be a boolean")
                    }
                    enabled = number.boolValue
                }
                for (index, key) in ["roll", "pitch", "yaw"].enumerated() {
                    let limit = index == 1 ? 90.0 : 180.0
                    guard let number = params[key] as? NSNumber,
                          CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite,
                          abs(number.doubleValue) <= limit
                    else { throw GuestAPIError.invalidRequest("\(key) must be a number between -\(limit) and \(limit) degrees") }
                    angles[index] = number.doubleValue
                }
            }
            guard vp_attitude_set(angles[0], angles[1], angles[2], enabled) else {
                throw GuestAPIError.operationFailed("Could not publish the attitude configuration")
            }
        }
        return vp_attitude_get() as? [String: Any] ?? [:]
    }
}
