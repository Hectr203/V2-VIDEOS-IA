import Foundation

// MARK: - Clipboard Transfer

/// What ⌘C and ⌘V carry between the Mac clipboard and the guest clipboard.
/// Only text and images are synced, and only when they are small: a file,
/// rich text or a large image stays on its own side.
public enum VPhoneClipboardTransfer {
    /// Largest text synced, in UTF-8 bytes.
    public static let maxTextBytes = 1024 * 1024
    /// Largest image synced, in encoded bytes.
    public static let maxImageBytes = 16 * 1024 * 1024

    /// Image types the guest decodes directly. Any other image is converted
    /// to PNG before it is sent.
    public static let guestImageTypes: Set<String> = ["public.png", "public.jpeg", "public.heic"]
    /// Image types taken from the Mac clipboard.
    public static let macImageTypes: Set<String> = guestImageTypes.union(["public.tiff"])
    /// Plain text on the Mac clipboard.
    public static let macTextType = "public.utf8-plain-text"

    public enum Kind: Equatable, Sendable {
        case text
        /// An image, read from the Mac clipboard as this type.
        case image(type: String)
    }

    /// The representation to send for a Mac clipboard whose types are listed
    /// in the owner's order of preference. The first text or image type wins,
    /// so a copied screenshot sends its image and copied text sends its text
    /// even when an image rendering is offered after it.
    public static func macKind(types: [String]) -> Kind? {
        for type in types {
            if type == macTextType {
                return .text
            }
            if macImageTypes.contains(type) {
                return .image(type: type)
            }
        }
        return nil
    }

    /// The representation to take from the guest clipboard. Text wins over an
    /// image, since an app that offers both usually copied text.
    public static func guestKind(text: String?, hasImage: Bool) -> Kind? {
        if let text, !text.isEmpty {
            return .text
        }
        return hasImage ? .image(type: "public.png") : nil
    }

    public static func fits(text: String) -> Bool {
        text.utf8.count <= maxTextBytes
    }

    public static func fits(image: Data) -> Bool {
        !image.isEmpty && image.count <= maxImageBytes
    }
}
