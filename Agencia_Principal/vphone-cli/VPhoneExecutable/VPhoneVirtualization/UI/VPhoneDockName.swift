import AppKit
import Foundation

/// Tells one guest's process from another's in the menu bar and the Dock.
///
/// Every guest is a `vphone-vm` inside the same `VPhone.bundle`, so by default
/// they all look and read alike.
enum VPhoneDockName {
    private typealias CurrentASN = @convention(c) () -> Unmanaged<CFTypeRef>?
    private typealias SetInformationItem = @convention(c) (
        Int32, CFTypeRef, CFString, CFTypeRef, UnsafeMutablePointer<Unmanaged<CFDictionary>?>?,
    ) -> OSStatus

    /// `kLSDefaultSessionID`.
    private static let defaultSession: Int32 = -2

    /// Names this process after the VM in Launch Services: the application
    /// menu title and whatever else reads the running application's display
    /// name.
    ///
    /// It does not reach the Dock's tooltip. A Dock process tile takes its
    /// label from the bundle URL's localized name ("VPhone.bundle"), uses the
    /// Launch Services name only when that lookup fails, and never reads it
    /// again; `label(_:)` covers the Dock instead.
    ///
    /// The setter is private; it is looked up at run time, and a missing
    /// symbol leaves the bundle name in place. Call after the application has
    /// checked in with Launch Services, that is from
    /// `applicationDidFinishLaunching` on.
    @MainActor
    static func set(_ name: String) {
        guard !name.isEmpty,
              let handle = dlopen(nil, RTLD_NOW),
              let currentASN = dlsym(handle, "_LSGetCurrentApplicationASN"),
              let setItem = dlsym(handle, "_LSSetApplicationInformationItem"),
              let displayNameKey = dlsym(handle, "_kLSDisplayNameKey")
        else { return }
        let asn = unsafeBitCast(currentASN, to: CurrentASN.self)()?.takeUnretainedValue()
        guard let asn else { return }
        let key = displayNameKey.assumingMemoryBound(to: CFString.self).pointee
        _ = unsafeBitCast(setItem, to: SetInformationItem.self)(defaultSession, asn, key, name as CFString, nil)
    }

    /// Draws the VM's name on this process's Dock tile. The icon is the one
    /// thing the Dock lets a process change about its own tile.
    @MainActor
    static func label(_ name: String) {
        guard !name.isEmpty else { return }
        let tile = NSApp.dockTile
        tile.contentView = VPhoneDockTileView(
            frame: NSRect(origin: .zero, size: tile.size),
            icon: NSApp.applicationIconImage,
            name: name,
        )
        tile.display()
    }

    /// The VM's name is its folder in the library, the one holding config.plist.
    static func name(forConfig config: URL) -> String {
        config.deletingLastPathComponent().lastPathComponent
    }
}

// MARK: - Dock Tile

/// The application icon with the VM's name on a plate across its lower part.
private final class VPhoneDockTileView: NSView {
    private let icon: NSImage
    private let name: String

    init(frame: NSRect, icon: NSImage, name: String) {
        self.icon = icon
        self.name = name
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func draw(_: NSRect) {
        icon.draw(in: bounds)

        let inset = bounds.width * 0.04
        let plate = NSRect(
            x: bounds.minX + inset,
            y: bounds.minY + inset,
            width: bounds.width - inset * 2,
            height: bounds.height * 0.3,
        )
        NSColor.black.withAlphaComponent(0.75).setFill()
        NSBezierPath(roundedRect: plate, xRadius: plate.height * 0.25, yRadius: plate.height * 0.25).fill()

        // Shrink to fit before truncating: names in a library often share a
        // prefix and differ only at the end.
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingMiddle
        let textWidth = plate.width - plate.height * 0.3
        var fontSize = plate.height * 0.6
        var text = attributed(size: fontSize, paragraph: paragraph)
        while text.size().width > textWidth, fontSize > plate.height * 0.36 {
            fontSize -= 1
            text = attributed(size: fontSize, paragraph: paragraph)
        }
        let textHeight = text.size().height
        text.draw(in: NSRect(
            x: plate.midX - textWidth / 2,
            y: plate.midY - textHeight / 2,
            width: textWidth,
            height: textHeight,
        ))
    }

    private func attributed(size: CGFloat, paragraph: NSParagraphStyle) -> NSAttributedString {
        NSAttributedString(string: name, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: .semibold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph,
        ])
    }
}
