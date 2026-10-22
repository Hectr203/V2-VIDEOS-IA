import Foundation
import IcliKit
import notify
import VphonedNative

/// `screen.unlock`: turn the display on and get past the Lock Screen.
///
/// A guest is at the Lock Screen, dark, after every boot, every SpringBoard
/// restart and every press of the side button, and a locked or dark screen
/// swallows taps and refuses app launches. The hardware keys only toggle, so a
/// script cannot tell what a press will do; this reads the state first and
/// does only what is needed.
///
/// The display comes on through `SBSUndimScreen`, which lights it without the
/// toggle a power press has. The Home button then dismisses the Lock Screen:
/// on a device without a passcode it goes straight to the Home Screen, and on
/// one with a passcode it raises the passcode pad, into which the passcode is
/// typed as keyboard events. SpringBoard's own `requestPasscodeUnlock` request
/// is not used: on a passcode-free device it lights the screen but leaves the
/// Lock Screen up (`autoUnlock = 0`), so it cannot replace the Home press.
///
/// See Research/Guest/screen_unlock.md.
enum GuestScreenUnlock {
    /// Two unlocks at once would press Home and type over each other.
    private static let exclusive = NSLock()
    private static let pollInterval = 0.1
    /// How long SpringBoard takes to raise the passcode pad after Home.
    private static let padDelay = 1.0

    static func unlock(passcode: String?, timeout: Double) throws -> [String: Any] {
        guard timeout.isFinite, (1 ... 60).contains(timeout) else {
            throw GuestAPIError.invalidRequest("timeout must be 1–60 seconds")
        }
        exclusive.lock()
        defer { exclusive.unlock() }

        let deadline = Date().addingTimeInterval(timeout)
        let before = startingState(until: deadline)

        if before.locked {
            let lock = try collectDeviceSnapshot()["lock"] as? [String: Any]
            let hasPasscode = lock?["passcode_enabled"] as? Bool ?? false
            if hasPasscode, passcode == nil {
                throw GuestAPIError.operationFailed("the device has a passcode; pass it as passcode")
            }
            try unlock(hasPasscode: hasPasscode, passcode: passcode, deadline: deadline)
        } else if before.screenOff {
            // Lit screen, already unlocked: just wake it.
            _ = vp_screen_undim()
        }

        guard wait(until: deadline, for: { !$0.screenOff }) else {
            throw GuestAPIError.operationFailed("the display did not turn on within \(Int(timeout)) s")
        }

        let after = state()
        return [
            "locked": after.locked,
            "screen_off": after.screenOff,
            "was_locked": before.locked,
            "was_screen_off": before.screenOff,
        ]
    }

    // MARK: - Lock Screen

    private static func unlock(hasPasscode: Bool, passcode: String?, deadline: Date) throws {
        // Light the screen first so the Home press lands on a live Lock
        // Screen rather than only waking it.
        if state().screenOff {
            _ = vp_screen_undim()
            _ = wait(until: min(Date().addingTimeInterval(1), deadline), for: { !$0.screenOff })
        }

        if hasPasscode, let passcode {
            _ = try pressButton("home")
            try enter(passcode, deadline: deadline)
            guard wait(until: deadline, for: { !$0.locked }) else {
                throw GuestAPIError.operationFailed("the device is still locked; the passcode was not accepted")
            }
            return
        }

        // No passcode: a Home press dismisses the Lock Screen. It is repeated
        // in case the first one landed while the display was still coming up.
        while state().locked {
            guard Date() < deadline else {
                throw GuestAPIError.operationFailed("the Lock Screen did not dismiss in time")
            }
            _ = try pressButton("home")
            _ = wait(until: min(Date().addingTimeInterval(0.6), deadline), for: { !$0.locked })
        }
    }

    /// Types the passcode into the pad Home raised. Digits go as the number
    /// keys of a hardware keyboard, which the numeric pad takes; anything else
    /// as text. A numeric pad submits on its last digit; a custom or
    /// alphanumeric one waits for Return.
    private static func enter(_ passcode: String, deadline: Date) throws {
        Thread.sleep(forTimeInterval: padDelay)
        guard state().locked else { return }
        let digits = passcode.unicodeScalars.map { ("0" ... "9").contains($0) ? Int($0.value) - 0x30 : -1 }
        if digits.allSatisfy({ $0 >= 0 }) {
            for digit in digits {
                // Keyboard page: 1…9 are 0x1E…0x26, 0 is 0x27.
                _ = try hidPress(page: 0x07, usage: digit == 0 ? 0x27 : 0x1D + digit)
                Thread.sleep(forTimeInterval: 0.06)
            }
        } else {
            _ = try typeText(passcode, delayMS: 60)
        }
        let submitted = min(Date().addingTimeInterval(1), deadline)
        if wait(until: submitted, for: { !$0.locked }) {
            return
        }
        _ = try pressKey("return")
    }

    // MARK: - State

    private struct State {
        let locked: Bool
        let screenOff: Bool
    }

    private static func state() -> State {
        let state = lockState()
        return State(
            locked: state["locked"] as? Bool ?? false,
            screenOff: state["screen_off"] as? Bool ?? false,
        )
    }

    /// The state to start from. Until SpringBoard has finished starting, the
    /// two notify states read "unlocked and lit" whatever the screen will
    /// show, so that reading is trusted only once SpringBoard says it is up.
    private static func startingState(until deadline: Date) -> State {
        while true {
            let now = state()
            if now.locked || now.screenOff || springBoardStarted() || Date() >= deadline {
                return now
            }
            Thread.sleep(forTimeInterval: pollInterval)
        }
    }

    /// SpringBoard stores a non-zero state under this name when its startup
    /// is over.
    private static func springBoardStarted() -> Bool {
        var token: Int32 = 0
        guard notify_register_check("com.apple.springboard.finishedstartup", &token) == 0 else { return true }
        defer { notify_cancel(token) }
        var value: UInt64 = 0
        return notify_get_state(token, &value) != 0 || value != 0
    }

    private static func wait(until deadline: Date, for condition: (State) -> Bool) -> Bool {
        while true {
            if condition(state()) {
                return true
            }
            guard Date() < deadline else { return false }
            Thread.sleep(forTimeInterval: pollInterval)
        }
    }
}
