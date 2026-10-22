import Foundation
import Testing
@testable import VPhoneCoreKit

struct ClipboardTransferTests {
    // MARK: - Mac to Guest

    @Test func `copied text sends its text`() {
        let types = ["public.utf8-plain-text", "public.rtf", "public.html"]
        #expect(VPhoneClipboardTransfer.macKind(types: types) == .text)
    }

    @Test func `a screenshot sends its image`() {
        #expect(VPhoneClipboardTransfer.macKind(types: ["public.png"]) == .image(type: "public.png"))
        #expect(VPhoneClipboardTransfer.macKind(types: ["public.tiff"]) == .image(type: "public.tiff"))
    }

    @Test func `the owner's first type wins`() {
        #expect(
            VPhoneClipboardTransfer.macKind(types: ["public.tiff", "public.utf8-plain-text"])
                == .image(type: "public.tiff"),
        )
        #expect(VPhoneClipboardTransfer.macKind(types: ["public.utf8-plain-text", "public.png"]) == .text)
    }

    @Test func `a copied file sends its name as text`() {
        let types = ["public.file-url", "com.apple.finder.node", "public.utf8-plain-text"]
        #expect(VPhoneClipboardTransfer.macKind(types: types) == .text)
    }

    @Test func `nothing syncable sends nothing`() {
        #expect(VPhoneClipboardTransfer.macKind(types: []) == nil)
        #expect(VPhoneClipboardTransfer.macKind(types: ["public.file-url", "public.rtf", "com.adobe.pdf"]) == nil)
    }

    @Test func `TIFF is converted before it reaches the guest`() {
        #expect(!VPhoneClipboardTransfer.guestImageTypes.contains("public.tiff"))
        #expect(VPhoneClipboardTransfer.macImageTypes.isSuperset(of: VPhoneClipboardTransfer.guestImageTypes))
    }

    // MARK: - Guest to Mac

    @Test func `guest text wins over a guest image`() {
        #expect(VPhoneClipboardTransfer.guestKind(text: "hello", hasImage: true) == .text)
        #expect(VPhoneClipboardTransfer.guestKind(text: "", hasImage: true) == .image(type: "public.png"))
        #expect(VPhoneClipboardTransfer.guestKind(text: nil, hasImage: true) == .image(type: "public.png"))
    }

    @Test func `an empty guest clipboard brings nothing back`() {
        #expect(VPhoneClipboardTransfer.guestKind(text: "", hasImage: false) == nil)
        #expect(VPhoneClipboardTransfer.guestKind(text: nil, hasImage: false) == nil)
    }

    // MARK: - Size

    @Test func `text is limited by its UTF-8 size`() {
        let limit = VPhoneClipboardTransfer.maxTextBytes
        #expect(VPhoneClipboardTransfer.fits(text: String(repeating: "a", count: limit)))
        #expect(!VPhoneClipboardTransfer.fits(text: String(repeating: "a", count: limit + 1)))
        // Three bytes each, so fewer characters than the limit still exceed it.
        #expect(!VPhoneClipboardTransfer.fits(text: String(repeating: "界", count: limit / 3 + 1)))
    }

    @Test func `images are limited and must not be empty`() {
        let limit = VPhoneClipboardTransfer.maxImageBytes
        #expect(VPhoneClipboardTransfer.fits(image: Data(count: limit)))
        #expect(!VPhoneClipboardTransfer.fits(image: Data(count: limit + 1)))
        #expect(!VPhoneClipboardTransfer.fits(image: Data()))
    }
}
