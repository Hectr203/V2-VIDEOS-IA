import Foundation
import VPhoneCoreKit

enum VPhoneFirmwareSourceSelection {
    private static var isTTY: Bool {
        isatty(FileHandle.standardInput.fileDescriptor) != 0
    }

    private static func err(_ s: String) {
        FileHandle.standardError.write(Data((s + "\n").utf8))
    }

    /// Resolve `vm create`'s iPhone/cloudOS sources, prompting on a TTY for
    /// whichever component the user didn't pass, from `device`'s builds (the
    /// iPhone list when nil). Non-interactive or fully specified → returns the
    /// inputs unchanged for caller validation.
    static func resolve(iphone: String?, cloudos: String?, device: String? = nil) throws -> VPhoneFirmwareSources {
        try VPhoneFirmwarePicker.resolve(
            iphone: iphone,
            cloudos: cloudos,
            device: device,
            isInteractive: isTTY,
            read: { readLine(strippingNewline: true) },
            write: { err($0) },
        )
    }
}
