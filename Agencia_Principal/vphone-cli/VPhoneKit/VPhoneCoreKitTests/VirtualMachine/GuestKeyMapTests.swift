import Testing
@testable import VPhoneCoreKit

/// The keys the virtual USB keyboard drops, and what the guest gets instead.
@Suite("Guest key map")
struct GuestKeyMapTests {
    @Test
    func `fn becomes the Apple keyboard 🌐 usage`() {
        #expect(VPhoneGuestKeyMap.functionKeyCode == 0x3F)
        #expect(VPhoneGuestKeyMap.globe == .init(page: 0xFF, usage: 0x03))
    }

    @Test
    func `the JIS input-mode keys become LANG1 and LANG2`() {
        #expect(VPhoneGuestKeyMap.usage(forDroppedKeyCode: 0x68) == .init(page: 0x07, usage: 0x90))
        #expect(VPhoneGuestKeyMap.usage(forDroppedKeyCode: 0x66) == .init(page: 0x07, usage: 0x91))
    }

    @Test
    func `keys the virtual keyboard carries are left to it`() {
        // A, Space, Escape, Caps Lock, Left Control, F1, Up Arrow, kVK_Function.
        for keyCode: UInt16 in [0x00, 0x31, 0x35, 0x39, 0x3B, 0x7A, 0x7E, 0x3F] {
            #expect(VPhoneGuestKeyMap.usage(forDroppedKeyCode: keyCode) == nil)
        }
    }

    @Test
    func `every forwarded usage is on a page the guest accepts from vphoned`() {
        for usage in VPhoneGuestKeyMap.droppedKeys.values {
            #expect([0x07, 0x0C].contains(usage.page))
        }
    }

    @Test
    func `keys held with 🌐 go as their keyboard usages, arrows restored`() {
        // 🌐H, 🌐A, 🌐C, 🌐N, 🌐Q, 🌐E.
        #expect(VPhoneGuestKeyMap.usage(whileGlobeHeld: 0x04) == .init(page: 0x07, usage: 0x0B))
        #expect(VPhoneGuestKeyMap.usage(whileGlobeHeld: 0x00) == .init(page: 0x07, usage: 0x04))
        #expect(VPhoneGuestKeyMap.usage(whileGlobeHeld: 0x08) == .init(page: 0x07, usage: 0x06))
        #expect(VPhoneGuestKeyMap.usage(whileGlobeHeld: 0x2D) == .init(page: 0x07, usage: 0x11))
        #expect(VPhoneGuestKeyMap.usage(whileGlobeHeld: 0x0C) == .init(page: 0x07, usage: 0x14))
        #expect(VPhoneGuestKeyMap.usage(whileGlobeHeld: 0x0E) == .init(page: 0x07, usage: 0x08))
        // macOS sends fn+← as Home; the guest gets 🌐←.
        #expect(VPhoneGuestKeyMap.usage(whileGlobeHeld: 0x73) == .init(page: 0x07, usage: 0x50))
        #expect(VPhoneGuestKeyMap.usage(whileGlobeHeld: 0x79) == .init(page: 0x07, usage: 0x51))
    }

    @Test
    func `the 🌐 table covers every letter and digit once`() {
        let usages = VPhoneGuestKeyMap.keyboardUsages.values
        for usage in UInt32(0x04) ... 0x27 {
            #expect(usages.filter { $0 == usage }.count == 1)
        }
    }
}
