import AppKit

// MARK: - Data Menu

/// Guest data the Mac reads and writes: files, Keychain, preference domains
/// and the clipboard.
extension VPhoneMenuController {
    func buildDataMenu() -> NSMenuItem {
        let item = NSMenuItem(title: "Data", action: nil, keyEquivalent: "")
        let menu = NSMenu(title: "Data")
        menu.autoenablesItems = false

        let fileBrowser = makeItem(
            "File Browser",
            action: #selector(openFiles),
            keyEquivalent: "f",
            modifiers: [.command, .shift],
            symbol: "folder",
        )
        fileBrowser.isEnabled = false
        connectFileBrowserItem = fileBrowser
        menu.addItem(fileBrowser)

        // Control-Command-K: Shift-Command-K is Device > Use Hardware Keyboard,
        // which comes first in the menu bar and would take the key.
        let keychainBrowser = makeItem(
            "Keychain Browser",
            action: #selector(openKeychain),
            keyEquivalent: "k",
            modifiers: [.command, .control],
            symbol: "key",
        )
        keychainBrowser.isEnabled = false
        connectKeychainBrowserItem = keychainBrowser
        menu.addItem(keychainBrowser)

        menu.addItem(NSMenuItem.separator())

        let settingsGet = makeItem(
            "Preferences",
            action: #selector(readSetting),
            keyEquivalent: "p",
            modifiers: [.command, .shift],
            symbol: "gearshape",
        )
        settingsGet.isEnabled = false
        settingsGetItem = settingsGet
        menu.addItem(settingsGet)

        let settingsSet = makeItem("Write Preference…", action: #selector(writeSetting), symbol: "pencil")
        settingsSet.isEnabled = false
        settingsSetItem = settingsSet
        menu.addItem(settingsSet)

        menu.addItem(NSMenuItem.separator())

        let clipGet = makeItem(
            "Guest Clipboard",
            action: #selector(getClipboard),
            keyEquivalent: "c",
            modifiers: [.command, .shift],
            symbol: "doc.on.clipboard",
        )
        clipGet.isEnabled = false
        clipboardGetItem = clipGet
        menu.addItem(clipGet)

        let clipSet = makeItem(
            "Set Clipboard Text…",
            action: #selector(setClipboardText),
            symbol: "character.cursor.ibeam",
        )
        clipSet.isEnabled = false
        clipboardSetItem = clipSet
        menu.addItem(clipSet)

        menu.addItem(makeItem(
            "Type ASCII from Mac Clipboard",
            action: #selector(typeFromClipboard),
            symbol: "keyboard",
        ))

        item.submenu = menu
        return item
    }

    func updateSettingsAvailability(available: Bool) {
        settingsGetItem?.isEnabled = available
        settingsSetItem?.isEnabled = available
    }

    func updateConnectAvailability(available: Bool) {
        connectFileBrowserItem?.isEnabled = available
        connectKeychainBrowserItem?.isEnabled = available
        connectDevModeStatusItem?.isEnabled = available
        connectPingItem?.isEnabled = available
        connectGuestHashItem?.isEnabled = available
    }

    func updateClipboardAvailability(available: Bool) {
        clipboardGetItem?.isEnabled = available
        clipboardSetItem?.isEnabled = available
    }

    @objc func openFiles() {
        onFilesPressed?()
    }

    @objc func openKeychain() {
        onKeychainPressed?()
    }

    // MARK: - Clipboard & Preferences

    @objc func getClipboard() {
        guestToolsWindowController.show(.getClipboard)
    }

    @objc func setClipboardText() {
        guestToolsWindowController.show(.setClipboard)
    }

    @objc func typeFromClipboard() {
        keySender.typeFromClipboard()
    }

    @objc func readSetting() {
        guestToolsWindowController.show(.readSetting)
    }

    @objc func writeSetting() {
        guestToolsWindowController.show(.writeSetting)
    }
}
