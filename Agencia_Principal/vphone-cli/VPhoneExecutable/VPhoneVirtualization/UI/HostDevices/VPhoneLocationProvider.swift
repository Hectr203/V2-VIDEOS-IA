import CoreLocation
import Foundation

/// Forwards the host Mac's location to the guest VM via vsock.
///
/// locationd never answers a client inside VPhone.bundle, so the Mac's
/// location comes from `Contents/Helpers/VPhoneLocation.app`: it asks for
/// permission and writes one JSON line per update, which this class forwards
/// to the guest.  Call `startForwarding()` when the guest reports "location"
/// capability.  Safe to call multiple times (e.g. after vphoned reconnects) -
/// re-sends the last known position.
@MainActor
class VPhoneLocationProvider: NSObject {
    struct ReplayPoint {
        let latitude: Double
        let longitude: Double
        let altitude: Double
        let horizontalAccuracy: Double
        let verticalAccuracy: Double
        let speed: Double
        let course: Double

        init(
            latitude: Double,
            longitude: Double,
            altitude: Double = 0,
            horizontalAccuracy: Double = 5,
            verticalAccuracy: Double = 8,
            speed: Double = 0,
            course: Double = -1,
        ) {
            self.latitude = latitude
            self.longitude = longitude
            self.altitude = altitude
            self.horizontalAccuracy = horizontalAccuracy
            self.verticalAccuracy = verticalAccuracy
            self.speed = speed
            self.course = course
        }
    }

    private let control: VPhoneGuestControl
    private var hostModeStarted = false

    private var helper: Process?
    private var helperInput: Pipe?
    private var helperReader: Task<Void, Never>?
    private var lastHostLocation: HostLocation?
    private var replayTask: Task<Void, Never>?
    private var replayName: String?
    var onAuthorizationFailure: (() -> Void)?
    /// Called once per sync, preset or replay when the guest refuses a
    /// location because its Location Services switch is off.
    var onGuestLocationServicesOff: (() -> Void)?
    private var reportedGuestServicesOff = false
    private var resendTask: Task<Void, Never>?

    var isReplaying: Bool {
        replayTask != nil
    }

    init(control: VPhoneGuestControl) {
        self.control = control
        super.init()
        control.onLocationFailure = { [weak self] error in self?.guestRefused(error) }
    }

    /// Begin sending location to the guest.  Safe to call on every (re)connect.
    func startForwarding() {
        stopReplay()
        hostModeStarted = true
        reportedGuestServicesOff = false
        if let last = lastHostLocation, abs(last.date.timeIntervalSinceNow) < 60 {
            forward(last)
        }
        guard helper == nil else { return }
        do {
            try launchHelper()
            print("[location] started host location tracking")
        } catch {
            print("[location] cannot start VPhoneLocation.app: \(error.localizedDescription)")
            hostModeStarted = false
            onAuthorizationFailure?()
        }
    }

    /// Stop forwarding host location updates.
    func stopForwarding() {
        if hostModeStarted {
            hostModeStarted = false
            stopHelper()
            resendTask?.cancel()
            resendTask = nil
            print("[location] stopped host location tracking")
        }
    }

    // MARK: - Location Helper

    private static var helperURL: URL {
        let executable = (Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0]))
            .resolvingSymlinksInPath()
        return executable
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Helpers/VPhoneLocation.app/Contents/MacOS/vphone-location")
    }

    private func launchHelper() throws {
        let process = Process()
        process.executableURL = Self.helperURL
        // The helper exits when this pipe closes, including when vphone-vm dies.
        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            Task { @MainActor in self?.helperDidExit(process, status: status) }
        }
        try process.run()
        helper = process
        helperInput = input
        helperReader = Task { @MainActor [weak self] in
            do {
                for try await line in output.fileHandleForReading.bytes.lines {
                    self?.handleHelperLine(line)
                }
            } catch {
                print("[location] VPhoneLocation.app output failed: \(error.localizedDescription)")
            }
        }
    }

    private func stopHelper() {
        helperReader?.cancel()
        helperReader = nil
        try? helperInput?.fileHandleForWriting.close()
        helperInput = nil
        helper?.terminate()
        helper = nil
    }

    private func helperDidExit(_ process: Process, status: Int32) {
        guard helper === process else { return }
        print("[location] VPhoneLocation.app exited with status \(status)")
        helper = nil
        helperInput = nil
        helperReader = nil
        stopForwarding()
    }

    private func handleHelperLine(_ line: String) {
        guard let message = try? JSONDecoder().decode(HelperMessage.self, from: Data(line.utf8)) else {
            print("[location] unreadable VPhoneLocation.app output: \(line)")
            return
        }
        if let rawStatus = message.authorization {
            handleAuthorization(CLAuthorizationStatus(rawValue: rawStatus) ?? .notDetermined)
        }
        if let location = message.location {
            let c = String(format: "%.6f,%.6f", location.latitude, location.longitude)
            print("[location] got location: \(c) (+/-\(String(format: "%.0f", location.horizontalAccuracy))m)")
            forward(location)
        }
    }

    private func handleAuthorization(_ status: CLAuthorizationStatus) {
        print("[location] authorization status: \(status.rawValue)")
        guard hostModeStarted else { return }
        switch status {
        case .denied, .restricted:
            stopForwarding()
            onAuthorizationFailure?()
        default:
            break
        }
    }

    /// Send a fixed simulated location to the guest.
    func sendPreset(name: String, latitude: Double, longitude: Double, altitude: Double = 0) {
        stopReplay()
        reportedGuestServicesOff = false
        sendSimulatedLocation(
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            horizontalAccuracy: 5,
            verticalAccuracy: 8,
            speed: 0,
            course: -1,
        )
        print("[location] applied preset '\(name)' (\(latitude), \(longitude))")
    }

    /// Start replaying a list of simulated locations at a fixed interval.
    func startReplay(
        name: String,
        points: [ReplayPoint],
        intervalSeconds: Double = 1.5,
        loop: Bool = true,
    ) {
        guard !points.isEmpty else {
            print("[location] replay '\(name)' ignored: no points")
            return
        }

        stopForwarding()
        stopReplay()
        reportedGuestServicesOff = false

        replayName = name
        let sleepNanos = UInt64((max(intervalSeconds, 0.1) * 1_000_000_000).rounded())
        print(
            "[location] starting replay '\(name)' (\(points.count) points, interval \(String(format: "%.1f", intervalSeconds))s, loop=\(loop))",
        )

        replayTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.replayTask = nil
                self.replayName = nil
            }

            var index = 0
            while !Task.isCancelled {
                let point = points[index]
                sendSimulatedLocation(
                    latitude: point.latitude,
                    longitude: point.longitude,
                    altitude: point.altitude,
                    horizontalAccuracy: point.horizontalAccuracy,
                    verticalAccuracy: point.verticalAccuracy,
                    speed: point.speed,
                    course: point.course,
                )

                index += 1
                if index >= points.count {
                    if loop {
                        index = 0
                    } else {
                        break
                    }
                }

                try? await Task.sleep(nanoseconds: sleepNanos)
            }

            if Task.isCancelled {
                print("[location] replay cancelled: \(name)")
            } else {
                print("[location] replay finished: \(name)")
            }
        }
    }

    /// Stop an active replay task.
    func stopReplay() {
        guard let replayTask else { return }
        replayTask.cancel()
        self.replayTask = nil
        if let replayName {
            print("[location] stopped replay: \(replayName)")
        }
        replayName = nil
    }

    private func forward(_ location: HostLocation) {
        lastHostLocation = location
        guard hostModeStarted else { return }
        resendTask?.cancel()
        resendTask = nil
        guard control.isConnected else {
            print("[location] forward: not connected, cached for later")
            return
        }
        control.sendLocation(
            latitude: location.latitude,
            longitude: location.longitude,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy,
            speed: location.speed,
            course: location.course,
        )
    }

    // MARK: - Guest Refusals

    private func guestRefused(_ error: Error) {
        guard case VPhoneGuestControl.ControlError.locationServicesOff = error else { return }
        if !reportedGuestServicesOff {
            reportedGuestServicesOff = true
            onGuestLocationServicesOff?()
        }
        // The Mac sends a fix only when it moves, so keep offering the last one
        // until someone turns Location Services on in the guest.
        guard hostModeStarted, let last = lastHostLocation, resendTask == nil else { return }
        resendTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard let self, !Task.isCancelled else { return }
            resendTask = nil
            forward(lastHostLocation ?? last)
        }
    }

    private func sendSimulatedLocation(
        latitude: Double,
        longitude: Double,
        altitude: Double,
        horizontalAccuracy: Double,
        verticalAccuracy: Double,
        speed: Double,
        course: Double,
    ) {
        guard control.isConnected else {
            print("[location] simulate: not connected, cached for later")
            return
        }

        control.sendLocation(
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            speed: speed,
            course: course,
        )
    }
}

// MARK: - Location Helper Messages

/// One fix from VPhoneLocation.app.
private struct HostLocation {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    let speed: Double
    let course: Double
    let date: Date
}

/// One line of VPhoneLocation.app output: an authorization status or a fix.
private struct HelperMessage: Decodable {
    let authorization: Int32?
    let latitude: Double?
    let longitude: Double?
    let altitude: Double?
    let horizontalAccuracy: Double?
    let verticalAccuracy: Double?
    let speed: Double?
    let course: Double?
    let timestamp: Double?

    var location: HostLocation? {
        guard let latitude, let longitude else { return nil }
        return HostLocation(
            latitude: latitude,
            longitude: longitude,
            altitude: altitude ?? 0,
            horizontalAccuracy: horizontalAccuracy ?? -1,
            verticalAccuracy: verticalAccuracy ?? -1,
            speed: speed ?? -1,
            course: course ?? -1,
            date: timestamp.map(Date.init(timeIntervalSince1970:)) ?? Date(),
        )
    }
}
