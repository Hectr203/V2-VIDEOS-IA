import Foundation

@MainActor
final class VPhoneGyroscopeTestGuest {
    var reply = VPhoneMotionReply(configuration: VPhoneMotionConfiguration(), providerRunning: true)
    var writes: [VPhoneMotionConfiguration] = []
    var completions: [CheckedContinuation<VPhoneMotionReply, any Error>] = []
    private var completed = 0

    func write(_ value: VPhoneMotionConfiguration) async throws -> VPhoneMotionReply {
        writes.append(value)
        return try await withCheckedThrowingContinuation { completions.append($0) }
    }

    func finish(failing: Bool = false) {
        let completion = completions.removeFirst()
        let value = writes[completed]
        completed += 1
        if failing {
            completion.resume(throwing: Failure.offline)
        } else {
            reply.configuration = value
            completion.resume(returning: reply)
        }
    }

    enum Failure: Error { case offline }
}

@main
struct VPhoneMotionModelTests {
    @MainActor static func waitFor(_ predicate: () -> Bool) async {
        for _ in 0 ..< 10000 {
            if predicate() {
                return
            }
            await Task.yield()
        }
        fatalError("Timed out waiting for the gyroscope request queue")
    }

    @MainActor static func main() async {
        let guest = VPhoneGyroscopeTestGuest()
        let model = VPhoneMotionModel(locale: Locale(identifier: "en_US"), read: { guest.reply }, write: {
            try await guest.write($0)
        })
        await model.connectionChanged(true)
        assert(model.canEdit && !model.enabled && guest.writes.isEmpty)

        // Rapid edits coalesce behind the single in-flight RPC. An old ack
        // must neither overwrite newer field text nor skip the final value.
        model.xText = "1"
        await waitFor { guest.writes.count == 1 }
        model.yText = "2"
        model.zText = "-3"
        model.enabled = true
        assert(guest.writes.count == 1)
        guest.finish()
        await waitFor { guest.writes.count == 2 }
        assert(guest.writes[1] == VPhoneMotionConfiguration(enabled: true, x: 1, y: 2, z: -3))
        assert(model.xText == "1" && model.yText == "2" && model.zText == "-3")
        model.reset()
        assert(model.enabled && model.xText == "0" && model.yText == "0" && model.zText == "0")
        guest.finish()
        await waitFor { guest.writes.count == 3 }
        assert(guest.writes[2] == VPhoneMotionConfiguration(enabled: true))
        guest.finish()
        await waitFor { !model.isSending }
        assert(!model.hasLocalChanges && model.error == nil)

        // Disable preserves configured axes; enable reuses them. A partial
        // numeric edit must not prevent the safety-critical disable operation.
        model.xText = "5"
        await waitFor { guest.writes.count == 4 }
        guest.finish()
        await waitFor { !model.isSending }
        model.enabled = false
        await waitFor { guest.writes.count == 5 }
        assert(!guest.writes[4].enabled && guest.writes[4].x == 5)
        guest.finish()
        await waitFor { !model.isSending }
        model.enabled = true
        await waitFor { guest.writes.count == 6 }
        assert(guest.writes[5].enabled && guest.writes[5].x == 5)
        guest.finish()
        await waitFor { !model.isSending }
        model.xText = "-"
        model.yText = "nan"
        model.zText = "1001"
        assert(model.hasInvalidAxes && guest.writes.count == 6)
        model.enabled = false
        await waitFor { guest.writes.count == 7 }
        assert(!guest.writes[6].enabled && guest.writes[6].x == 5)
        guest.finish()
        await waitFor { !model.isSending }
        model.reset()
        await waitFor { guest.writes.count == 8 }
        assert(guest.writes[7] == VPhoneMotionConfiguration())
        assert(!model.hasInvalidAxes)
        guest.finish()
        await waitFor { !model.isSending }

        // Keep the desired values on a failed write and retry the same full
        // configuration, rather than presenting unacknowledged values as sent.
        model.xText = "7"
        await waitFor { guest.writes.count == 9 }
        guest.finish(failing: true)
        await waitFor { !model.isSending }
        assert(model.canRetry && model.xText == "7" && model.hasLocalChanges)
        model.retry()
        await waitFor { guest.writes.count == 10 }
        assert(guest.writes[9].x == 7)
        guest.finish()
        await waitFor { !model.isSending }
        assert(!model.hasLocalChanges && model.error == nil)

        // Disconnect during a write, then reconnect. The old request must
        // finish before the pending state is resent, and cannot clear it.
        model.zText = "9"
        await waitFor { guest.writes.count == 11 }
        await model.connectionChanged(false)
        assert(!model.canEdit && !model.providerRunning)
        guest.reply.configuration = VPhoneMotionConfiguration()
        await model.connectionChanged(true)
        assert(model.zText == "9" && guest.writes.count == 11)
        guest.finish()
        await waitFor { guest.writes.count == 12 }
        assert(guest.writes[11].x == 7 && guest.writes[11].z == 9)
        guest.finish()
        await waitFor { !model.isSending }
        assert(!model.hasLocalChanges)

        model.yText = "1"
        await waitFor { guest.writes.count == 13 }
        model.yText = "4"
        guest.finish(failing: true)
        await waitFor { guest.writes.count == 14 }
        assert(guest.writes[13].y == 4)
        guest.finish()
        await waitFor { !model.isSending }
        assert(model.error == nil && !model.hasLocalChanges)

        // A cancelled/stale initial read cannot replace the new connection's
        // values, nor can reading the guest itself trigger a write.
        var reads: [CheckedContinuation<VPhoneMotionReply, any Error>] = []
        let reconnect = VPhoneMotionModel(read: {
            try await withCheckedThrowingContinuation { reads.append($0) }
        }, write: { _ in fatalError("A read unexpectedly triggered a write") })
        let first = Task { await reconnect.connectionChanged(true) }
        await waitFor { reads.count == 1 }
        await reconnect.connectionChanged(false)
        let second = Task { await reconnect.connectionChanged(true) }
        await waitFor { reads.count == 2 }
        reads[1].resume(returning: VPhoneMotionReply(
            configuration: VPhoneMotionConfiguration(enabled: true, x: 3), providerRunning: true,
        ))
        await second.value
        reads[0].resume(returning: VPhoneMotionReply(
            configuration: VPhoneMotionConfiguration(x: 99), providerRunning: false,
        ))
        await first.value
        assert(reconnect.enabled && reconnect.xValue == 3 && reconnect.providerRunning)

        let decimal = VPhoneMotionModel(locale: Locale(identifier: "de_DE"), read: { guest.reply }, write: {
            VPhoneMotionReply(configuration: $0, providerRunning: true)
        })
        await decimal.connectionChanged(true)
        decimal.xText = "1,25"
        await waitFor { !decimal.hasLocalChanges }
        assert(decimal.configuration.x == 1.25)

        let attitude = VPhoneMotionModel(
            ranges: [-180 ... 180, -90 ... 90, -180 ... 180],
            read: { VPhoneMotionReply(configuration: VPhoneMotionConfiguration(), providerRunning: true) },
            write: { VPhoneMotionReply(configuration: $0, providerRunning: true) },
        )
        await attitude.connectionChanged(true)
        attitude.yText = "91"
        assert(attitude.hasInvalidAxes && attitude.configuration.y == 0)
        attitude.enabled = true // Still works with invalid pitch text.
        await waitFor { !attitude.hasLocalChanges }
        assert(attitude.configuration.enabled && attitude.configuration.y == 0)
        attitude.reset()
        await waitFor { !attitude.hasLocalChanges }
        assert(attitude.enabled && !attitude.hasInvalidAxes && attitude.yText == "0")
        attitude.xText = "180"
        attitude.yText = "-90"
        attitude.zText = "-180"
        await waitFor { !attitude.hasLocalChanges }
        assert(attitude.configuration == VPhoneMotionConfiguration(enabled: true, x: 180, y: -90, z: -180))
        attitude.xText = "181"
        assert(attitude.hasInvalidAxes && attitude.configuration.x == 180)
        print("Motion model tests passed: ordered/coalesced writes, toggle, reset, invalid input, retry, reconnect, stale reads, locale and attitude bounds")
    }
}
