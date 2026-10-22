import AppKit
import Foundation
import VPhoneCoreKit

// MARK: - Clipboard Sync

/// ⌘C, ⌘X and ⌘V in the VM window carry the clipboard through vphoned.
/// Paste sends a changed Mac clipboard to the guest before the guest pastes;
/// copy and cut bring the guest clipboard back once the guest has written it.
/// A copy made in the guest without those keys (by touch, or by an app)
/// reaches the Mac when the VM window resigns key, which is when the user
/// goes to paste it somewhere else.
/// Only small text and images are synced (`VPhoneClipboardTransfer`).
@MainActor
final class VPhoneClipboardSync {
    private weak var control: VPhoneGuestControl?
    /// The Mac clipboard as last sent to or written from the guest. An
    /// unchanged Mac clipboard is not sent again, so a guest copy made by
    /// touch is not overwritten by an older Mac one.
    private var syncedMacChangeCount: Int?
    /// The guest clipboard as last sent to or written from the Mac, or as
    /// adopted when the window became key or the guest connected. Only a
    /// later guest change is brought to the Mac on resign key. The count
    /// starts again with each vphoned instance, so it is kept with the
    /// instance that gave it and never compared across one.
    private var syncedGuest: (instance: String?, changeCount: Int)?
    /// Moves on with every adopt and every sync. A read that finishes after
    /// a later one started is dropped, so a slow read (a guest request may
    /// wait out the 120 s socket timeout) neither holds up nor undoes a newer
    /// one.
    private var guestGeneration = 0
    private var isAdoptingForConnection = false
    private var copyTask: Task<Void, Never>?

    /// How long copy waits for the guest to write its clipboard.
    private static let copyPolls = 20
    private static let copyPollInterval: Duration = .milliseconds(100)

    init(control: VPhoneGuestControl) {
        self.control = control
    }

    var isAvailable: Bool {
        guard let control else { return false }
        return control.isConnected && control.guestCapabilities.contains("clipboard")
    }

    // MARK: - Actions

    func paste() {
        guard let control else { return }
        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount
        let payload = changeCount == syncedMacChangeCount ? nil : Self.macPayload(from: pasteboard)
        Task {
            var sent = false
            if let payload {
                do {
                    switch payload {
                    case let .text(text): try await control.clipboardSet(text: text)
                    case let .image(data): try await control.clipboardSet(imageData: data)
                    }
                    syncedMacChangeCount = changeCount
                    sent = true
                } catch {
                    print("[clipboard] Mac to guest: \(error)")
                }
            }
            Self.sendChord(usage: Self.usageV, to: control)
            // Read behind the paste key, which does not change the clipboard,
            // so the paste is not held up. The Mac clipboard the guest now
            // holds is not brought back on resign key, where it would replace
            // rich text with its plain text.
            if sent {
                await adopt(from: control)
            }
        }
    }

    func copy(cut: Bool) {
        guard let control else { return }
        copyTask?.cancel()
        copyTask = Task {
            // The count read before the key, so any later change is this copy.
            let before = try? await control.clipboardInfoAfterQueuedInput().changeCount
            Self.sendChord(usage: cut ? Self.usageX : Self.usageC, to: control)
            guard let before else { return }
            for _ in 0 ..< Self.copyPolls {
                try? await Task.sleep(for: Self.copyPollInterval)
                guard !Task.isCancelled else { return }
                guard let info = try? await control.clipboardInfoAfterQueuedInput(),
                      info.changeCount != before
                else { continue }
                await writeToMac(info, control: control)
                return
            }
        }
    }

    // MARK: - Window Focus

    /// Takes the guest clipboard as it is now as synced. Called when the
    /// window becomes key: a change made while it was not, by automation or
    /// Guest Tools, was not copied by the user here.
    func adoptGuestClipboard() {
        guard let control, isAvailable else { return }
        Task { await adopt(from: control) }
    }

    /// Brings a guest copy made since the last sync to the Mac. Called when
    /// the window resigns key, so text copied by touch can be pasted in a Mac
    /// app. Without a count from this vphoned there is nothing known to be new.
    func bringGuestCopyToMac() {
        guard let control, isAvailable,
              let synced = syncedGuest, synced.instance == control.connectedInstance
        else { return }
        let generation = guestGeneration
        Task {
            guard let info = try? await control.clipboardInfoAfterQueuedInput(),
                  generation == guestGeneration, synced.instance == control.connectedInstance,
                  info.changeCount != synced.changeCount
            else { return }
            await writeToMac(info, control: control)
        }
    }

    /// Follows the connection the window polls. A vphoned that has connected
    /// gives the first count, so a copy made before the window ever resigned
    /// key still reaches the Mac; a disconnect forgets it.
    func connectionChanged(connected: Bool) {
        guard connected else {
            syncedGuest = nil
            return
        }
        guard let control, isAvailable, !isAdoptingForConnection,
              syncedGuest == nil || syncedGuest?.instance != control.connectedInstance
        else { return }
        isAdoptingForConnection = true
        Task {
            await adopt(from: control)
            isAdoptingForConnection = false
        }
    }

    /// Takes the count read now as synced, unless a later adopt or sync
    /// started before the read came back.
    private func adopt(from control: VPhoneGuestControl) async {
        guestGeneration += 1
        let generation = guestGeneration
        let instance = control.connectedInstance
        guard let info = try? await control.clipboardInfoAfterQueuedInput(),
              generation == guestGeneration, instance == control.connectedInstance
        else { return }
        markGuestSynced(info.changeCount, instance: instance)
    }

    private func markGuestSynced(_ changeCount: Int, instance: String?) {
        guestGeneration += 1
        syncedGuest = (instance, changeCount)
    }

    // MARK: - Guest to Mac

    /// Writes the guest clipboard to the Mac. The count is taken as synced
    /// even when nothing is written, so content too large or of another kind
    /// is not tried again on every resign key.
    private func writeToMac(_ info: VPhoneGuestControl.ClipboardContent, control: VPhoneGuestControl) async {
        markGuestSynced(info.changeCount, instance: control.connectedInstance)
        let pasteboard = NSPasteboard.general
        switch VPhoneClipboardTransfer.guestKind(text: info.text, hasImage: info.hasImage) {
        case .text:
            guard let text = info.text, VPhoneClipboardTransfer.fits(text: text) else { return }
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        case .image:
            guard let png = try? await control.clipboardImagePNG(),
                  VPhoneClipboardTransfer.fits(image: png)
            else { return }
            pasteboard.clearContents()
            pasteboard.setData(png, forType: .png)
        case nil:
            return
        }
        syncedMacChangeCount = pasteboard.changeCount
    }

    // MARK: - Mac to Guest

    private enum Payload {
        case text(String)
        case image(Data)
    }

    private static func macPayload(from pasteboard: NSPasteboard) -> Payload? {
        let types = pasteboard.types?.map(\.rawValue) ?? []
        switch VPhoneClipboardTransfer.macKind(types: types) {
        case .text:
            guard let text = pasteboard.string(forType: .string), VPhoneClipboardTransfer.fits(text: text)
            else { return nil }
            return .text(text)
        case let .image(type):
            guard var data = pasteboard.data(forType: NSPasteboard.PasteboardType(type)) else { return nil }
            if !VPhoneClipboardTransfer.guestImageTypes.contains(type) {
                guard let png = NSBitmapImageRep(data: data)?.representation(using: .png, properties: [:])
                else { return nil }
                data = png
            }
            return VPhoneClipboardTransfer.fits(image: data) ? .image(data) : nil
        case nil:
            return nil
        }
    }

    // MARK: - Keys

    /// Keyboard page (0x07) usages.
    private static let usageC: UInt32 = 0x06
    private static let usageV: UInt32 = 0x19
    private static let usageX: UInt32 = 0x1B
    private static let usageLeftCommand: UInt32 = 0xE3

    /// ⌘ plus one key, queued behind any input already sent.
    private static func sendChord(usage: UInt32, to control: VPhoneGuestControl) {
        control.sendHIDDown(page: 0x07, usage: usageLeftCommand)
        control.sendHIDPress(page: 0x07, usage: usage)
        control.sendHIDUp(page: 0x07, usage: usageLeftCommand)
    }
}
