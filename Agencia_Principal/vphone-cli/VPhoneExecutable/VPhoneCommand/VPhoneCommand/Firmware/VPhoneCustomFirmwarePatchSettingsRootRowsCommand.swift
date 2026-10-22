import ArgumentParser
import FirmwarePatcher
import Foundation

/// Operates only on the installer's staged pristine backup. The common Mach-O
/// installer handles signing, ownership, selection, receipt and restoration.
struct VPhoneCustomFirmwarePatchSettingsRootRowsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "patch-settings-root-rows",
        abstract: "Hide four root rows in reviewed 24A435 Preferences; caller must re-sign",
    )

    @Argument(help: "Pristine Preferences Mach-O staged for patching", transform: URL.init(fileURLWithPath:))
    var binary: URL

    @Flag(help: "Discover and validate all edits without writing")
    var dryRun = false

    func run() throws {
        let original = try Data(contentsOf: binary)
        let result = try CustomFirmwareSettingsRows.patchPreferences(original)
        for edit in result.edits {
            let before = edit.before.map { String(format: "%02x", $0) }.joined()
            let after = edit.after.map { String(format: "%02x", $0) }.joined()
            print("\(edit.identifier): file+0x\(String(edit.fileOffset, radix: 16)) \(before) -> \(after)")
        }
        if !dryRun {
            try result.data.write(to: binary, options: .atomic)
        }
    }
}
