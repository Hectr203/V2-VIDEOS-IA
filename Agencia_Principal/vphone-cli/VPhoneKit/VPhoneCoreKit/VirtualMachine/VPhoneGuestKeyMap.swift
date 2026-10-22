// MARK: - Guest Key Map

/// Mac keys the virtual USB keyboard cannot carry, and the HID usage the guest
/// gets for each instead, by way of vphoned.
///
/// `VZUSBKeyboardConfiguration` is a boot-protocol keyboard: its report holds
/// the eight page-7 modifiers (0xE0–0xE7) and six page-7 keys in 0x00–0x91,
/// nothing else. `_VZKeyboard` first maps each Mac virtual key code to an
/// internal index through a 179-entry table, and drops codes the table has no
/// index for (macOS 27.0.1, Virtualization 259). Measured against that table
/// and the report descriptor, the keys that never reach a guest are:
///
/// - **fn / 🌐** (`kVK_Function`, 0x3F): has an index, but no report field. On
///   an iPad, 🌐 switches the input source and starts the 🌐 shortcuts; Apple's
///   keyboards send it as Apple vendor top-case page 0xFF, usage 0x03, which
///   iPadOS honours from any keyboard service.
/// - the JIS keys 英数 / かな / ¥ / _ / keypad `,`, which switch the Japanese
///   input mode and type their characters;
/// - Context Menu, Help/Insert, and the volume and mute keys.
public enum VPhoneGuestKeyMap {
    public struct Usage: Hashable, Sendable {
        public let page: UInt32
        public let usage: UInt32

        public init(page: UInt32, usage: UInt32) {
            self.page = page
            self.usage = usage
        }
    }

    /// `kVK_Function`, which AppKit reports in a flags-changed event.
    public static let functionKeyCode: UInt16 = 0x3F

    /// The 🌐 key of an Apple keyboard: vendor top-case page, keyboard fn.
    public static let globe = Usage(page: 0xFF, usage: 0x03)

    /// Key-down / key-up codes `_VZKeyboard` drops, with the usage to send.
    public static let droppedKeys: [UInt16: Usage] = [
        0x66: Usage(page: 0x07, usage: 0x91), // JIS 英数 → LANG2
        0x68: Usage(page: 0x07, usage: 0x90), // JIS かな → LANG1
        0x5D: Usage(page: 0x07, usage: 0x89), // JIS ¥ → International3
        0x5E: Usage(page: 0x07, usage: 0x87), // JIS _ → International1
        0x5F: Usage(page: 0x07, usage: 0x85), // JIS keypad , → Keypad Comma
        0x6E: Usage(page: 0x07, usage: 0x65), // Context Menu → Application
        0x72: Usage(page: 0x07, usage: 0x49), // Help / Insert → Insert
        0x48: Usage(page: 0x0C, usage: 0xE9), // Volume Up
        0x49: Usage(page: 0x0C, usage: 0xEA), // Volume Down
        0x4A: Usage(page: 0x0C, usage: 0xE2), // Mute
    ]

    /// The usage a key-down or key-up with `keyCode` needs sent by hand, or nil
    /// for a key the virtual keyboard carries itself.
    public static func usage(forDroppedKeyCode keyCode: UInt16) -> Usage? {
        droppedKeys[keyCode]
    }

    // MARK: - Keys Pressed With 🌐

    /// The usage for a key pressed while 🌐 is held.
    ///
    /// 🌐 reaches the guest through vphoned, from a different keyboard service
    /// than the virtual USB keyboard, and iPadOS only combines keys from one
    /// service: 🌐 from vphoned with H from the virtual keyboard is not 🌐H. So
    /// while 🌐 is held, the other keys go through vphoned as well.
    ///
    /// macOS rewrites fn with an arrow into Home, End, Page Up and Page Down
    /// before AppKit sees it; held with 🌐, those are turned back into the
    /// arrows the user pressed, which is what iPadOS's 🌐 shortcuts bind.
    public static func usage(whileGlobeHeld keyCode: UInt16) -> Usage? {
        if let arrow = globeArrows[keyCode] {
            return Usage(page: 0x07, usage: arrow)
        }
        return keyboardUsages[keyCode].map { Usage(page: 0x07, usage: $0) }
            ?? droppedKeys[keyCode]
    }

    /// fn+arrow as macOS delivers it → the arrow's usage.
    static let globeArrows: [UInt16: UInt32] = [
        0x73: 0x50, // Home → Left
        0x77: 0x4F, // End → Right
        0x74: 0x52, // Page Up → Up
        0x79: 0x51, // Page Down → Down
    ]

    /// `kVK_*` → keyboard page (7) usage, for the keys a US/ISO keyboard has.
    static let keyboardUsages: [UInt16: UInt32] = [
        0x00: 0x04, 0x0B: 0x05, 0x08: 0x06, 0x02: 0x07, 0x0E: 0x08, 0x03: 0x09, // a b c d e f
        0x05: 0x0A, 0x04: 0x0B, 0x22: 0x0C, 0x26: 0x0D, 0x28: 0x0E, 0x25: 0x0F, // g h i j k l
        0x2E: 0x10, 0x2D: 0x11, 0x1F: 0x12, 0x23: 0x13, 0x0C: 0x14, 0x0F: 0x15, // m n o p q r
        0x01: 0x16, 0x11: 0x17, 0x20: 0x18, 0x09: 0x19, 0x0D: 0x1A, 0x07: 0x1B, // s t u v w x
        0x10: 0x1C, 0x06: 0x1D, // y z
        0x12: 0x1E, 0x13: 0x1F, 0x14: 0x20, 0x15: 0x21, 0x17: 0x22, // 1 2 3 4 5
        0x16: 0x23, 0x1A: 0x24, 0x1C: 0x25, 0x19: 0x26, 0x1D: 0x27, // 6 7 8 9 0
        0x24: 0x28, 0x35: 0x29, 0x33: 0x2A, 0x30: 0x2B, 0x31: 0x2C, // Return Esc Delete Tab Space
        0x1B: 0x2D, 0x18: 0x2E, 0x21: 0x2F, 0x1E: 0x30, 0x2A: 0x31, // - = [ ] \
        0x29: 0x33, 0x27: 0x34, 0x32: 0x35, 0x2B: 0x36, 0x2F: 0x37, 0x2C: 0x38, // ; ' ` , . /
        0x0A: 0x64, // ISO §
        0x7A: 0x3A, 0x78: 0x3B, 0x63: 0x3C, 0x76: 0x3D, 0x60: 0x3E, 0x61: 0x3F, // F1-F6
        0x62: 0x40, 0x64: 0x41, 0x65: 0x42, 0x6D: 0x43, 0x67: 0x44, 0x6F: 0x45, // F7-F12
        0x75: 0x4C, // Forward Delete
        0x7C: 0x4F, 0x7B: 0x50, 0x7D: 0x51, 0x7E: 0x52, // Right Left Down Up
    ]
}
