import Foundation

/// Keeps the guest's system time zone on the Mac's. The guest has no cellular
/// network and at most a simulated location, so its automatic time zone has
/// little to go on; vphoned pins the zone the host sends instead.
///
/// Call `start()` when the guest reports the "timezone" capability, on every
/// connect: it sends the Mac's zone, then again whenever the Mac's changes.
/// vphoned answers a zone it already has without touching anything.
@MainActor
class VPhoneTimeZoneSync {
    private let control: VPhoneGuestControl
    private var observer: NSObjectProtocol?
    private var sending: Task<Void, Never>?

    init(control: VPhoneGuestControl) {
        self.control = control
    }

    func start() {
        if observer == nil {
            observer = NotificationCenter.default.addObserver(
                forName: .NSSystemTimeZoneDidChange,
                object: nil,
                queue: .main,
            ) { [weak self] _ in
                Task { @MainActor in self?.send() }
            }
        }
        send()
    }

    func stop() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
        sending?.cancel()
        sending = nil
    }

    private func send() {
        NSTimeZone.resetSystemTimeZone()
        let identifier = TimeZone.current.identifier
        let previous = sending
        sending = Task { [control] in
            // Two quick changes on the Mac must reach the guest in order.
            await previous?.value
            guard !Task.isCancelled else { return }
            do {
                let changed = try await control.setTimeZone(identifier)
                print("[timezone] guest \(changed ? "set to" : "already on") \(identifier)")
            } catch {
                print("[timezone] could not set the guest to \(identifier): \(error)")
            }
        }
    }
}
