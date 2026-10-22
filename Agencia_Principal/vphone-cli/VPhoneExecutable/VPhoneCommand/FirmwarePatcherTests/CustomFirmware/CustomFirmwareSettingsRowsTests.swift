import CryptoKit
import FirmwarePatcher
import Foundation
import Testing

@Suite("Settings root rows")
struct CustomFirmwareSettingsRowsTests {
    @Test(arguments: [0, 31, 64, 4096])
    func `rejects unreviewed input`(size: Int) {
        #expect(throws: (any Error).self) {
            try CustomFirmwareSettingsRows.patchPreferences(Data(repeating: 0, count: size))
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["VPHONE_SETTINGS_FIXTURE"] != nil))
    func `reviewed fixture and undo`() throws {
        let path = try #require(ProcessInfo.processInfo.environment["VPHONE_SETTINGS_FIXTURE"])
        let original = try Data(contentsOf: URL(fileURLWithPath: path))
        let result = try CustomFirmwareSettingsRows.patchPreferences(original)
        let hash = SHA256.hash(data: result.data).map { String(format: "%02x", $0) }.joined()
        #expect(hash == "de1d55444059bd4f017aa945de625ff834a07b9ae56f346732856b087e25d74e")
        #expect(result.edits.count == 5)
        var restored = result.data
        for edit in result.edits {
            #expect(edit.before != edit.after)
            restored.replaceSubrange(edit.fileOffset ..< edit.fileOffset + 4, with: edit.before)
        }
        #expect(restored == original)
        #expect(throws: (any Error).self) {
            try CustomFirmwareSettingsRows.patchPreferences(result.data)
        }
    }
}
