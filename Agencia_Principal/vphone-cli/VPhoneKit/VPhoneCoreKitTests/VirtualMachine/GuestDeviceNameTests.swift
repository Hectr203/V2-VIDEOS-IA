import Foundation
import Testing
@testable import VPhoneCoreKit

struct GuestDeviceNameTests {
    @Test(arguments: [
        "lab-a",
        "Jacky's iPhone",
        "Jacky’s iPhone",
        "  padded  ",
        "测试机 01",
        "📱 Lab",
        "👩‍💻 Desk",
        String(repeating: "a", count: 255),
        String(repeating: "测", count: 85), // 255 bytes
    ])
    func `accepts printable names`(name: String) throws {
        try VPhoneGuestDeviceName.validate(name)
        #expect(VPhoneGuestDeviceName.isValid(name))
    }

    @Test(arguments: ["", " ", "   ", "\u{3000}"])
    func `rejects blank names`(name: String) {
        #expect(throws: VPhoneGuestDeviceNameError.empty) { try VPhoneGuestDeviceName.validate(name) }
    }

    @Test(arguments: ["a\nb", "a\rb", "a\tb", "a\0b", "a\u{1B}b", "a\u{7F}b", "a\u{85}b", "a\u{9F}b", "name\n"])
    func `rejects control characters`(name: String) {
        #expect(throws: VPhoneGuestDeviceNameError.controlCharacter) { try VPhoneGuestDeviceName.validate(name) }
    }

    @Test func `rejects names over 255 UTF-8 bytes`() {
        #expect(throws: VPhoneGuestDeviceNameError.tooLong(byteCount: 256)) {
            try VPhoneGuestDeviceName.validate(String(repeating: "a", count: 256))
        }
        // 86 three-byte characters: 86 characters, 258 bytes.
        #expect(throws: VPhoneGuestDeviceNameError.tooLong(byteCount: 258)) {
            try VPhoneGuestDeviceName.validate(String(repeating: "测", count: 86))
        }
    }
}
