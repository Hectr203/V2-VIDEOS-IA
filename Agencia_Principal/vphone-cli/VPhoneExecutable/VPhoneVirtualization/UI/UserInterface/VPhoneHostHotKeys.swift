import Darwin
import Foundation

// MARK: - Host Hot Keys

/// Turns off the Mac's own keyboard shortcuts that a guest needs, while a VM
/// window is key.
///
/// macOS handles its symbolic hot keys — Spotlight, input-source switching,
/// the 🌐 shortcuts — in the window server, before the VM window's event
/// monitor sees the key, and `capturesSystemKeys` does not reach them: with the
/// default ⌃Space Spotlight binding, ⌃Space in an iPad guest opened Spotlight
/// on the Mac instead of switching the guest's input source, and 🌐H showed the
/// Mac's desktop. iPadOS uses the same keys for itself.
///
/// While a VM window is key, every enabled hot key on Space, and every one on
/// fn with a letter, digit, punctuation or arrow key, is switched off through
/// SkyLight's `CGSSetSymbolicHotKeyEnabled` (the call window switchers use for
/// ⌘Tab), and switched back on when the window resigns key and when the
/// process exits. F-key, media-key and ⌘Tab bindings are left alone.
///
/// The switch is the window server's, so a crash would leave the shortcuts
/// off: the suspended set is written to `suspended-hotkeys.plist` with this
/// process's pid, and the next VM process to start turns them back on when that
/// pid is gone.
@MainActor
final class VPhoneHostHotKeys {
    static let shared = VPhoneHostHotKeys()

    private typealias GetValue = @convention(c) (
        Int32, UnsafeMutablePointer<UInt16>, UnsafeMutablePointer<UInt16>, UnsafeMutablePointer<UInt32>,
    ) -> Int32
    private typealias IsEnabled = @convention(c) (Int32) -> Bool
    private typealias SetEnabled = @convention(c) (Int32, Bool) -> Int32

    private struct SkyLight {
        let get: GetValue
        let isEnabled: IsEnabled
        let setEnabled: SetEnabled
    }

    private nonisolated static let skyLight: SkyLight? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW),
              let get = dlsym(handle, "CGSGetSymbolicHotKeyValue"),
              let isEnabled = dlsym(handle, "CGSIsSymbolicHotKeyEnabled"),
              let setEnabled = dlsym(handle, "CGSSetSymbolicHotKeyEnabled")
        else { return nil }
        return SkyLight(
            get: unsafeBitCast(get, to: GetValue.self),
            isEnabled: unsafeBitCast(isEnabled, to: IsEnabled.self),
            setEnabled: unsafeBitCast(setEnabled, to: SetEnabled.self),
        )
    }()

    /// The hot keys this process turned off. Read at exit, from `atexit`.
    private nonisolated(unsafe) static var suspended: [Int32] = []

    private nonisolated static let spaceKeyCode: UInt16 = 0x31
    private nonisolated static let functionModifier: UInt32 = 0x800000
    /// Symbolic hot key identifiers run well below this.
    private static let identifierLimit: Int32 = 512

    private init() {
        atexit {
            VPhoneHostHotKeys.resumeSuspended()
        }
    }

    // MARK: - Suspend / Resume

    /// Turns the conflicting shortcuts off, once, until `resume()`.
    func suspend() {
        guard Self.suspended.isEmpty, let skyLight = Self.skyLight else { return }
        var turnedOff: [Int32] = []
        for identifier in 0 ..< Self.identifierLimit where skyLight.isEnabled(identifier) {
            var character: UInt16 = 0
            var keyCode: UInt16 = 0
            var modifiers: UInt32 = 0
            guard skyLight.get(identifier, &character, &keyCode, &modifiers) == 0,
                  Self.conflicts(keyCode: keyCode, modifiers: modifiers),
                  skyLight.setEnabled(identifier, false) == 0
            else { continue }
            turnedOff.append(identifier)
        }
        Self.suspended = turnedOff
        Self.record(turnedOff)
    }

    /// Turns back on whatever `suspend()` turned off.
    func resume() {
        Self.resumeSuspended()
    }

    private nonisolated static func resumeSuspended() {
        guard !suspended.isEmpty, let skyLight else { return }
        for identifier in suspended {
            _ = skyLight.setEnabled(identifier, true)
        }
        suspended = []
        record([])
    }

    /// Whether a Mac shortcut would take a key the guest needs: anything on
    /// Space (Spotlight, input sources), or fn with a key iPadOS also binds to
    /// 🌐 — letters, digits and punctuation (`kVK_*` 0x00–0x32).
    ///
    /// The arrows carry the fn flag whenever they are pressed, so a binding on
    /// fn and an arrow is often just an arrow with modifiers — ⌃← and ⌃→ for
    /// Spaces, ⌃↑ for Mission Control. Only the arrows on fn alone, which is
    /// 🌐 with an arrow, count.
    nonisolated static func conflicts(keyCode: UInt16, modifiers: UInt32) -> Bool {
        if keyCode == spaceKeyCode {
            return true
        }
        guard modifiers & functionModifier != 0 else { return false }
        if (0x7B ... 0x7E).contains(keyCode) {
            return modifiers & deviceIndependentModifiers == functionModifier
        }
        return keyCode <= 0x32
    }

    /// Shift, Control, Option, Command, fn (`NSEvent.ModifierFlags`' bits).
    private nonisolated static let deviceIndependentModifiers: UInt32 = 0xFF0000

    // MARK: - Crash Recovery

    private nonisolated static var recordURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("vphone", isDirectory: true)
            .appendingPathComponent("suspended-hotkeys.plist")
    }

    private nonisolated static func record(_ identifiers: [Int32]) {
        let url = recordURL
        if identifiers.isEmpty {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let plist: [String: Any] = ["pid": Int(getpid()), "hotkeys": identifiers.map(Int.init)]
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Turns back on the shortcuts a VM process that is no longer running left
    /// off.
    func recoverAfterCrash() {
        guard let skyLight = Self.skyLight,
              let data = try? Data(contentsOf: Self.recordURL),
              let plist = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any],
              let pid = plist["pid"] as? Int,
              let identifiers = plist["hotkeys"] as? [Int]
        else { return }
        // Still running: its own resume will turn them back on.
        if pid != Int(getpid()), kill(pid_t(pid), 0) == 0 || errno == EPERM {
            return
        }
        for identifier in identifiers {
            _ = skyLight.setEnabled(Int32(identifier), true)
        }
        try? FileManager.default.removeItem(at: Self.recordURL)
        print("[keys] turned back on \(identifiers.count) Mac shortcuts a stopped VM had suspended")
    }
}
