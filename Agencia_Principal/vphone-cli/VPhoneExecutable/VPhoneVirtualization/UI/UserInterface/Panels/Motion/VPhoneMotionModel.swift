import Foundation
import Observation

struct VPhoneMotionConfiguration: Equatable, Sendable {
    var enabled = false
    var x = 0.0
    var y = 0.0
    var z = 0.0
}

struct VPhoneMotionReply: Sendable {
    var configuration: VPhoneMotionConfiguration
    var providerRunning: Bool
}

// MARK: - Live Motion Controls

@MainActor
@Observable
final class VPhoneMotionModel {
    var enabled = false {
        didSet {
            guard !applyingGuest, enabled != oldValue else { return }
            // Disabling must work even while an axis contains a partial edit.
            var value = parsedConfiguration ?? configuration
            value.enabled = enabled
            enqueue(value)
        }
    }

    var xText = "0" {
        didSet { axesChanged() }
    }

    var yText = "0" {
        didSet { axesChanged() }
    }

    var zText = "0" {
        didSet { axesChanged() }
    }

    private(set) var isConnected = false
    private(set) var isReading = false
    private(set) var isSending = false
    private(set) var hasLoaded = false
    private(set) var providerRunning = false
    private(set) var error: String?
    private(set) var hasLocalChanges = false
    private(set) var configuration = VPhoneMotionConfiguration()

    @ObservationIgnored private let read: @MainActor () async throws -> VPhoneMotionReply
    @ObservationIgnored private let write: @MainActor (VPhoneMotionConfiguration) async throws -> VPhoneMotionReply
    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let ranges: [ClosedRange<Double>]
    @ObservationIgnored private let rejectionMessage: String
    @ObservationIgnored private var applyingGuest = false
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var pending: VPhoneMotionConfiguration?
    @ObservationIgnored private var writer: Task<Void, Never>?

    init(
        locale: Locale = .current,
        ranges: [ClosedRange<Double>] = [-1000 ... 1000, -1000 ... 1000, -1000 ... 1000],
        rejectionMessage: String = "Guest did not apply the gyroscope configuration",
        read: @escaping @MainActor () async throws -> VPhoneMotionReply,
        write: @escaping @MainActor (VPhoneMotionConfiguration) async throws -> VPhoneMotionReply,
    ) {
        self.locale = locale
        precondition(ranges.count == 3)
        self.ranges = ranges
        self.rejectionMessage = rejectionMessage
        self.read = read
        self.write = write
    }

    var canEdit: Bool {
        isConnected && hasLoaded && !isReading
    }

    var hasInvalidAxes: Bool {
        parsedConfiguration == nil
    }

    var canRetry: Bool {
        canEdit && !isSending && hasLocalChanges && error != nil
    }

    /// Computed key-path bindings let the steppers repair a partially typed axis.
    var xValue: Double {
        get { number(xText, range: ranges[0]) ?? configuration.x }
        set { xText = formatted(newValue) }
    }

    var yValue: Double {
        get { number(yText, range: ranges[1]) ?? configuration.y }
        set { yText = formatted(newValue) }
    }

    var zValue: Double {
        get { number(zText, range: ranges[2]) ?? configuration.z }
        set { zText = formatted(newValue) }
    }

    private func number(_ text: String, range: ClosedRange<Double>) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: locale.decimalSeparator ?? ".", with: ".")
        guard let value = Double(normalized), value.isFinite, range.contains(value) else { return nil }
        return value
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(0 ... 6)).locale(locale))
    }

    private var parsedConfiguration: VPhoneMotionConfiguration? {
        guard let x = number(xText, range: ranges[0]), let y = number(yText, range: ranges[1]),
              let z = number(zText, range: ranges[2]) else { return nil }
        return VPhoneMotionConfiguration(enabled: enabled, x: x, y: y, z: z)
    }

    private func axesChanged() {
        guard !applyingGuest, let value = parsedConfiguration, value != configuration else { return }
        enqueue(value)
    }

    private func applyFields(_ value: VPhoneMotionConfiguration) {
        applyingGuest = true
        defer { applyingGuest = false }
        enabled = value.enabled
        xText = formatted(value.x)
        yText = formatted(value.y)
        zText = formatted(value.z)
        configuration = value
    }

    func reset() {
        guard canEdit else { return }
        let zero = VPhoneMotionConfiguration(enabled: enabled)
        applyFields(zero)
        enqueue(zero)
    }

    func retry() {
        startWriter()
    }

    /// A read belongs to the view's connection task; an accepted edit's write
    /// survives closing the panel. Never apply a read/ack from an old connection.
    func connectionChanged(_ connected: Bool) async {
        generation &+= 1
        let current = generation
        isConnected = connected
        hasLoaded = false
        if hasLocalChanges {
            pending = configuration
        }
        guard connected else {
            isReading = false
            providerRunning = false
            return
        }
        isReading = true
        defer {
            if generation == current {
                isReading = false
            }
        }
        do {
            let reply = try await read()
            guard generation == current, isConnected, !Task.isCancelled else { return }
            providerRunning = reply.providerRunning
            if !hasLocalChanges {
                applyFields(reply.configuration)
            }
            hasLoaded = true
            error = nil
            startWriter()
        } catch {
            guard generation == current, !Task.isCancelled else { return }
            self.error = String(describing: error)
        }
    }

    private func enqueue(_ value: VPhoneMotionConfiguration) {
        guard canEdit else { return }
        configuration = value
        pending = value
        hasLocalChanges = true
        error = nil
        startWriter()
    }

    private func startWriter() {
        guard writer == nil, isConnected, hasLoaded, pending != nil else { return }
        writer = Task { await drain() }
    }

    private func drain() async {
        isSending = true
        defer {
            isSending = false
            writer = nil
        }
        while isConnected, hasLoaded, let value = pending {
            pending = nil
            let current = generation
            do {
                let reply = try await write(value)
                guard generation == current, isConnected else { continue }
                providerRunning = reply.providerRunning
                // The guest returns the persisted configuration, not merely
                // transport success. Keep newer edits in the fields untouched.
                guard reply.configuration == value else {
                    error = rejectionMessage
                    pending = configuration
                    break
                }
                hasLocalChanges = pending != nil
                error = nil
            } catch {
                guard generation == current, isConnected else { continue }
                if pending != nil {
                    continue
                } // A newer edit supersedes this failed write.
                self.error = String(describing: error)
                pending = configuration
                break
            }
        }
    }
}
