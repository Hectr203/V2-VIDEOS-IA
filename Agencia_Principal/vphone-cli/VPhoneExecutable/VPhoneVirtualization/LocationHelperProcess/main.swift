// vphone-location — reads the Mac's location for vphone-vm.
//
// locationd never answers a client whose executable sits in a generic bundle:
// from VPhone.bundle/Contents/MacOS, requestWhenInUseAuthorization neither
// prompts nor changes the status. A process inside an .app is prompted, so
// StageBundle.sh wraps this program in Contents/Helpers/VPhoneLocation.app with
// the usage descriptions and their translations.
//
// vphone-vm starts it when Sync Host Location is turned on. It writes one JSON
// object per line to stdout: the authorization status whenever it changes, then
// each fix. It exits when vphone-vm closes its stdin.

import AppKit
import CoreLocation

struct VPhoneLocationHelperMessage: Encodable {
    var authorization: Int32?
    var latitude: Double?
    var longitude: Double?
    var altitude: Double?
    var horizontalAccuracy: Double?
    var verticalAccuracy: Double?
    var speed: Double?
    var course: Double?
    var timestamp: Double?
}

func emit(_ message: VPhoneLocationHelperMessage) {
    guard var line = try? JSONEncoder().encode(message) else { return }
    line.append(0x0A)
    FileHandle.standardOutput.write(line)
}

final class VPhoneLocationHelperDelegate: NSObject, CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        emit(VPhoneLocationHelperMessage(authorization: status.rawValue))
        if status == .authorized || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        emit(VPhoneLocationHelperMessage(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy,
            speed: location.speed,
            course: location.course,
            timestamp: location.timestamp.timeIntervalSince1970,
        ))
    }

    func locationManager(_: CLLocationManager, didFailWithError error: any Error) {
        // kCLErrorLocationUnknown is transient: there is no fix yet.
        guard (error as NSError).code != CLError.locationUnknown.rawValue else { return }
        FileHandle.standardError.write(Data("[location] \(error.localizedDescription)\n".utf8))
    }
}

Thread.detachNewThread {
    while !FileHandle.standardInput.availableData.isEmpty {}
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = VPhoneLocationHelperDelegate()
let manager = CLLocationManager()
manager.delegate = delegate
manager.desiredAccuracy = kCLLocationAccuracyBest
manager.requestWhenInUseAuthorization()
app.run()
