import AppKit
import Foundation

// MARK: - Host Key Events

/// Key presses replayed as the Mac would deliver them to the VM window: the
/// modifiers as flags-changed events, the key as a key-down and key-up. Each
/// goes through `VPhoneApplication.takeKeyEvent(_:view:)` and, unless that
/// keeps it, to the VM view's own key handling and the virtual USB keyboard —
/// the path a real keyboard takes — so the automation socket can check what
/// reaches the guest from the Mac side.
///
/// The view is handed the event directly rather than through
/// `NSApp.sendEvent(_:)`: AppKit only routes key events to a key window, and
/// a test should not have to bring the VM window to the front. macOS's own
/// shortcuts are not involved; these events never pass the window server.
@MainActor
enum VPhoneHostKeyEvents {
    enum Error: Swift.Error, CustomStringConvertible {
        case unknownKey(String)
        case noWindow

        var description: String {
            switch self {
            case let .unknownKey(name): "unknown key \"\(name)\""
            case .noWindow: "the VM view has no window"
            }
        }
    }

    /// Modifier names, their `kVK_*` code and flag, in press order.
    private static let modifiers: [(names: [String], keyCode: UInt16, flag: NSEvent.ModifierFlags)] = [
        (["fn", "globe"], 0x3F, .function),
        (["ctrl", "control"], 0x3B, .control),
        (["opt", "option", "alt"], 0x3A, .option),
        (["shift"], 0x38, .shift),
        (["cmd", "command"], 0x37, .command),
    ]

    private static let keys: [String: UInt16] = {
        var keys: [String: UInt16] = [
            "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05, "z": 0x06, "x": 0x07,
            "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C, "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10,
            "t": 0x11, "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "6": 0x16, "5": 0x17, "=": 0x18,
            "9": 0x19, "7": 0x1A, "-": 0x1B, "8": 0x1C, "0": 0x1D, "]": 0x1E, "o": 0x1F, "u": 0x20,
            "[": 0x21, "i": 0x22, "p": 0x23, "l": 0x25, "j": 0x26, "'": 0x27, "k": 0x28, ";": 0x29,
            "\\": 0x2A, ",": 0x2B, "/": 0x2C, "n": 0x2D, "m": 0x2E, ".": 0x2F, "`": 0x32,
            "return": 0x24, "enter": 0x24, "tab": 0x30, "space": 0x31, "delete": 0x33, "backspace": 0x33,
            "esc": 0x35, "escape": 0x35, "forwarddelete": 0x75, "home": 0x73, "end": 0x77,
            "pageup": 0x74, "pagedown": 0x79, "left": 0x7B, "right": 0x7C, "down": 0x7D, "up": 0x7E,
            "eisu": 0x66, "kana": 0x68, "yen": 0x5D, "underscore": 0x5E, "menu": 0x6E, "insert": 0x72,
        ]
        for (index, code) in [0x7A, 0x78, 0x63, 0x76, 0x60, 0x61, 0x62, 0x64, 0x65, 0x6D, 0x67, 0x6F].enumerated() {
            keys["f\(index + 1)"] = UInt16(code)
        }
        return keys
    }()

    /// Presses a combination such as `ctrl+space`, `cmd+shift+3`, `fn` or
    /// `vk:0x66`, and releases it.
    static func press(_ combination: String, in view: NSView) async throws {
        guard let window = view.window else { throw Error.noWindow }
        let parts = combination.lowercased().split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces) }

        var held: [(keyCode: UInt16, flag: NSEvent.ModifierFlags)] = []
        var key: UInt16?
        // Modifiers alone (`fn`, `ctrl+shift`) are pressed and released with no key.
        for part in parts {
            if let modifier = modifiers.first(where: { $0.names.contains(part) }) {
                held.append((modifier.keyCode, modifier.flag))
            } else if part.hasPrefix("vk:"), let code = UInt16(part.dropFirst(3).replacingOccurrences(of: "0x", with: ""), radix: 16) {
                key = code
            } else if let code = keys[part] {
                key = code
            } else {
                throw Error.unknownKey(part)
            }
        }

        var flags: NSEvent.ModifierFlags = []
        for modifier in held {
            flags.insert(modifier.flag)
            send(.flagsChanged, keyCode: modifier.keyCode, flags: flags, in: window)
            try await Task.sleep(for: .milliseconds(30))
        }
        if let key {
            send(.keyDown, keyCode: key, flags: flags, in: window)
            try await Task.sleep(for: .milliseconds(60))
            send(.keyUp, keyCode: key, flags: flags, in: window)
            try await Task.sleep(for: .milliseconds(30))
        } else {
            try await Task.sleep(for: .milliseconds(60))
        }
        for modifier in held.reversed() {
            flags.remove(modifier.flag)
            send(.flagsChanged, keyCode: modifier.keyCode, flags: flags, in: window)
            try await Task.sleep(for: .milliseconds(30))
        }
    }

    private static func send(_ type: NSEvent.EventType, keyCode: UInt16, flags: NSEvent.ModifierFlags, in window: NSWindow) {
        guard let view = window.firstResponder as? VPhoneVirtualMachineView ?? window.contentView?.firstVMView,
              let event = NSEvent.keyEvent(
                  with: type,
                  location: .zero,
                  modifierFlags: flags,
                  timestamp: ProcessInfo.processInfo.systemUptime,
                  windowNumber: window.windowNumber,
                  context: nil,
                  characters: "",
                  charactersIgnoringModifiers: "",
                  isARepeat: false,
                  keyCode: keyCode,
              ) else { return }
        if (NSApp as? VPhoneApplication)?.takeKeyEvent(event, view: view) == true {
            return
        }
        switch type {
        case .keyDown: view.keyDown(with: event)
        case .keyUp: view.keyUp(with: event)
        default: view.flagsChanged(with: event)
        }
    }
}

private extension NSView {
    /// The VM view inside this view, when the window's first responder is not it.
    var firstVMView: VPhoneVirtualMachineView? {
        if let view = self as? VPhoneVirtualMachineView {
            return view
        }
        for child in subviews {
            if let view = child.firstVMView {
                return view
            }
        }
        return nil
    }
}
