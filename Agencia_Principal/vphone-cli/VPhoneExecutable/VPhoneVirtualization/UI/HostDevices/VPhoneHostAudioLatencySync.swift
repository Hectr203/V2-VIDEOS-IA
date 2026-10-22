import CoreAudio
import Foundation

/// What the Mac's output device adds after its mixer: the frames between the
/// mix of an IO cycle and the listener's ear, at the device's nominal rate.
///
/// The CoreAudio headers sum the device's and its stream's latency
/// (`kAudioDevicePropertyLatency`, `kAudioStreamPropertyLatency`): the time
/// from the HAL's output time to the ear. A player native to the Mac holds
/// its picture back by that: measured on one clock at the Mac's mixer, an
/// AVPlayer window plays its sound 14.5 ms early on the built-in speakers,
/// whose device and stream latency come to 15.6 ms, and 140 ms early on
/// AirPods. That sum is the figure. The safety offset and IO buffer, which
/// the HAL mixes ahead of the output time, are left out: measured at the
/// Mac's mixer the guest's sound was already 8 ms ahead of its picture on the
/// built-in speakers, so what lies before the mixer is covered by what the
/// plugin measures in flight. They are read and logged all the same. On a
/// MacBook Pro's speakers: 60 + 690 frames, 15.6 ms.
struct VPhoneHostAudioLatency: Equatable {
    var deviceFrames: UInt32
    var safetyOffsetFrames: UInt32
    var streamFrames: UInt32
    var bufferFrames: UInt32
    var sampleRate: Double

    var frames: UInt64 {
        UInt64(deviceFrames) + UInt64(streamFrames)
    }

    var seconds: Double {
        sampleRate > 0 ? Double(frames) / sampleRate : 0
    }

    var summary: String {
        String(
            format: "%.1f ms (device %u + stream %u frames at %.0f Hz; safety offset %u and buffer %u not counted)",
            seconds * 1000, deviceFrames, streamFrames, sampleRate, safetyOffsetFrames, bufferFrames,
        )
    }
}

/// Keeps the guest's sound plugin told what the Mac's output device adds
/// after its mixer, so the guest's speaker reports the whole latency and a
/// player in the guest keeps its picture with the sound also on a Bluetooth
/// output. See Research/Guest/virtio_sound.md §6 (Picture against sound).
///
/// The VM's `VZHostAudioOutputStreamSink` plays to "the same device that
/// AudioQueueNewOutput uses" (its header), and an output queue created
/// without a device UID plays to the default output device: that is the
/// device measured here. Virtualization's own buffering before the mixer is
/// not in this figure; the plugin measures that part itself.
///
/// Call `start()` when the guest reports the "audio_host_latency" capability,
/// on every connect: it sends the current figure, then again whenever the
/// default output device, or its latency, safety offset, buffer, rate or
/// streams, change. Changes come in bursts while a Bluetooth device
/// connects, so a send waits for them to settle.
@MainActor
class VPhoneHostAudioLatencySync {
    private static let settleDelay: Duration = .milliseconds(500)

    private let control: VPhoneGuestControl
    private var observedDevice = AudioObjectID(kAudioObjectUnknown)
    private var listener: AudioObjectPropertyListenerBlock?
    private var pending: Task<Void, Never>?
    private var sending: Task<Void, Never>?
    private var lastSent: Double?

    init(control: VPhoneGuestControl) {
        self.control = control
    }

    func start() {
        if listener == nil {
            let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                MainActor.assumeIsolated {
                    self?.scheduleSend()
                }
            }
            self.listener = listener
            var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
            AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
        }
        // A new connection may be a new guest: send even an unchanged figure.
        lastSent = nil
        send()
    }

    func stop() {
        pending?.cancel()
        pending = nil
        sending?.cancel()
        sending = nil
        if let listener {
            var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
            observe(device: AudioObjectID(kAudioObjectUnknown))
        }
        listener = nil
    }

    private func scheduleSend() {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: Self.settleDelay)
            guard !Task.isCancelled else { return }
            self?.send()
        }
    }

    private func send() {
        let device = Self.defaultOutputDevice()
        observe(device: device)
        guard device != kAudioObjectUnknown, let latency = Self.latency(of: device) else {
            print("[audio] no default output device to measure")
            return
        }
        let seconds = latency.seconds
        guard seconds != lastSent else { return }
        lastSent = seconds
        let name = Self.name(of: device) ?? "device \(device)"
        let previous = sending
        sending = Task { [control] in
            // Two quick changes on the Mac must reach the guest in order.
            await previous?.value
            guard !Task.isCancelled else { return }
            do {
                let changed = try await control.setHostAudioLatency(seconds)
                print("[audio] \(name): \(latency.summary), guest \(changed ? "updated" : "already had it")")
            } catch {
                print("[audio] could not send the output latency of \(name): \(error)")
            }
        }
    }

    // MARK: - Device listeners

    private static let deviceSelectors: [(AudioObjectPropertySelector, AudioObjectPropertyScope)] = [
        (kAudioDevicePropertyLatency, kAudioObjectPropertyScopeOutput),
        (kAudioDevicePropertySafetyOffset, kAudioObjectPropertyScopeOutput),
        (kAudioDevicePropertyBufferFrameSize, kAudioObjectPropertyScopeGlobal),
        (kAudioDevicePropertyNominalSampleRate, kAudioObjectPropertyScopeGlobal),
        (kAudioDevicePropertyStreams, kAudioObjectPropertyScopeOutput),
    ]

    /// Moves the device listeners to `device`, or removes them for
    /// `kAudioObjectUnknown`.
    private func observe(device: AudioObjectID) {
        guard device != observedDevice, let listener else { return }
        for (selector, scope) in Self.deviceSelectors {
            if observedDevice != kAudioObjectUnknown {
                var address = Self.address(selector, scope)
                AudioObjectRemovePropertyListenerBlock(observedDevice, &address, .main, listener)
            }
            if device != kAudioObjectUnknown {
                var address = Self.address(selector, scope)
                AudioObjectAddPropertyListenerBlock(device, &address, .main, listener)
            }
        }
        observedDevice = device
    }

    // MARK: - CoreAudio

    private static func address(
        _ selector: AudioObjectPropertySelector,
        _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func value<T: BitwiseCopyable>(
        _ object: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        initial: T,
    ) -> T? {
        var address = address(selector, scope)
        var value = initial
        var size = UInt32(MemoryLayout<T>.size)
        let status = AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    static func defaultOutputDevice() -> AudioObjectID {
        value(
            AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice,
            initial: AudioObjectID(kAudioObjectUnknown),
        ) ?? AudioObjectID(kAudioObjectUnknown)
    }

    /// The device's figure; the stream latency is the largest of its output
    /// streams'. Nil when the device does not answer its rate.
    static func latency(of device: AudioObjectID) -> VPhoneHostAudioLatency? {
        let output = kAudioObjectPropertyScopeOutput
        guard let rate = value(device, kAudioDevicePropertyNominalSampleRate, initial: Float64(0)), rate > 0 else {
            return nil
        }
        let streamFrames = outputStreams(of: device)
            .compactMap { value($0, kAudioStreamPropertyLatency, initial: UInt32(0)) }
            .max() ?? 0
        return VPhoneHostAudioLatency(
            deviceFrames: value(device, kAudioDevicePropertyLatency, output, initial: UInt32(0)) ?? 0,
            safetyOffsetFrames: value(device, kAudioDevicePropertySafetyOffset, output, initial: UInt32(0)) ?? 0,
            streamFrames: streamFrames,
            bufferFrames: value(device, kAudioDevicePropertyBufferFrameSize, initial: UInt32(0)) ?? 0,
            sampleRate: rate,
        )
    }

    private static func outputStreams(of device: AudioObjectID) -> [AudioStreamID] {
        var address = address(kAudioDevicePropertyStreams, kAudioObjectPropertyScopeOutput)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var streams = [AudioStreamID](repeating: 0, count: Int(size) / MemoryLayout<AudioStreamID>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &streams) == noErr else { return [] }
        return Array(streams.prefix(Int(size) / MemoryLayout<AudioStreamID>.size))
    }

    private static func name(of device: AudioObjectID) -> String? {
        var address = address(kAudioObjectPropertyName)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &name) == noErr else { return nil }
        return name?.takeRetainedValue() as String?
    }
}
