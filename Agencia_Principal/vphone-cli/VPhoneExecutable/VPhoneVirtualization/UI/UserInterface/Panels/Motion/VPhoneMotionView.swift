import SwiftUI

enum VPhoneMotionSensor {
    case gyroscope, attitude

    var identifier: String {
        self == .gyroscope ? "gyroscope" : "attitude"
    }

    var axes: [String] {
        self == .gyroscope ? ["X", "Y", "Z"] : ["Roll", "Pitch", "Yaw"]
    }

    var ranges: [ClosedRange<Double>] {
        self == .gyroscope ? [-1000 ... 1000, -1000 ... 1000, -1000 ... 1000] : [-180 ... 180, -90 ... 90, -180 ... 180]
    }

    var units: String {
        self == .gyroscope ? "rad/s" : "°"
    }

    var step: Double {
        self == .gyroscope ? 0.1 : 1
    }
}

struct VPhoneMotionView: View {
    let model: VPhoneMotionModel
    let sensor: VPhoneMotionSensor
    let connected: @MainActor () -> Bool

    var body: some View {
        VPhoneMotionEditor(model: model, sensor: sensor)
            .task(id: connected()) { await model.connectionChanged(connected()) }
    }
}

struct VPhoneMotionEditor: View {
    @Bindable var model: VPhoneMotionModel
    let sensor: VPhoneMotionSensor

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Toggle(isOn: $model.enabled) {
                        Text("Enable Simulation", bundle: VPhoneLocalization.bundle)
                    }
                    .toggleStyle(.checkbox)
                    .accessibilityIdentifier(sensor.identifier + "-enabled")
                    Text("Changes sync to the guest immediately. Disabling keeps your axis values.", bundle: VPhoneLocalization.bundle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if sensor == .attitude {
                        Text("Angles describe a stationary pose. Zero is face up. Enable simulation before launching the guest app.", bundle: VPhoneLocalization.bundle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    VPhoneMotionAxisRow(sensor: sensor, index: 0, text: $model.xText, value: $model.xValue)
                    VPhoneMotionAxisRow(sensor: sensor, index: 1, text: $model.yText, value: $model.yValue)
                    VPhoneMotionAxisRow(sensor: sensor, index: 2, text: $model.zText, value: $model.zValue)
                    if model.hasInvalidAxes {
                        Text(sensor == .gyroscope ? "Enter a number from -1000 to 1000 for each axis." : "Roll and yaw: -180 to 180°. Pitch: -90 to 90°.", bundle: VPhoneLocalization.bundle)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Button { model.reset() } label: {
                        Label {
                            Text("Reset", bundle: VPhoneLocalization.bundle)
                        } icon: { Image(systemName: "arrow.counterclockwise") }
                    }
                    .accessibilityIdentifier(sensor.identifier + "-reset")
                    .help(Text("Set all three axes to zero", bundle: VPhoneLocalization.bundle))
                } header: {
                    Text(sensor == .gyroscope ? "Angular Velocity" : "Device Attitude", bundle: VPhoneLocalization.bundle)
                }
            }
            .formStyle(.grouped)
            .disabled(!model.canEdit)
            Divider()
            VPhoneMotionSyncStatus(model: model, sensor: sensor)
        }
    }
}

struct VPhoneMotionAxisRow: View {
    let sensor: VPhoneMotionSensor
    let index: Int
    @Binding var text: String
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 8) {
            Text(VPhoneLocalization.text(sensor.axes[index]))
                .font(.system(.body, design: .monospaced))
            TextField(VPhoneLocalization.text(sensor.axes[index]), text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .accessibilityLabel(VPhoneLocalization.text(sensor.axes[index]))
                .accessibilityIdentifier(sensor.identifier + "-axis-" + sensor.axes[index].lowercased())
            Text(verbatim: sensor.units).foregroundStyle(.secondary)
            Stepper(VPhoneLocalization.text(sensor.axes[index]), value: $value, in: sensor.ranges[index], step: sensor.step)
                .labelsHidden()
                .accessibilityLabel(VPhoneLocalization.text(sensor.axes[index]))
        }
    }
}

struct VPhoneMotionSyncStatus: View {
    let model: VPhoneMotionModel
    let sensor: VPhoneMotionSensor

    var body: some View {
        HStack(spacing: 8) {
            if !model.isConnected {
                Text("Guest not connected", bundle: VPhoneLocalization.bundle)
            } else if model.isReading || model.isSending {
                ProgressView().controlSize(.small)
                Text("Syncing…", bundle: VPhoneLocalization.bundle)
            } else if let error = model.error {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                Text(VPhoneLocalization.text(error)).textSelection(.enabled)
            } else if model.hasLoaded {
                if model.providerRunning {
                    Text("Synced", bundle: VPhoneLocalization.bundle)
                } else if sensor == .attitude {
                    Text("Enable the device attitude patch and relaunch the guest app.", bundle: VPhoneLocalization.bundle)
                } else {
                    Text("Waiting for sensor service…", bundle: VPhoneLocalization.bundle)
                }
            }
            Spacer(minLength: 0)
            if model.canRetry {
                Button { model.retry() } label: { Text("Retry", bundle: VPhoneLocalization.bundle) }
            } else if model.isConnected, !model.hasLoaded, !model.isReading {
                Button { Task { await model.connectionChanged(true) } } label: {
                    Text("Retry", bundle: VPhoneLocalization.bundle)
                }
            }
        }
        .font(.system(.caption, design: .monospaced))
        .padding(8)
        .background(.bar)
    }
}

#Preview {
    let sample = VPhoneMotionReply(
        configuration: VPhoneMotionConfiguration(enabled: true, x: 1.25, y: 0, z: -0.75),
        providerRunning: true,
    )
    let model = VPhoneMotionModel(read: { sample }, write: {
        VPhoneMotionReply(configuration: $0, providerRunning: true)
    })
    return VPhoneMotionView(model: model, sensor: .gyroscope, connected: { true })
        .frame(width: 440, height: 380)
}
