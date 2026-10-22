import AppKit

// MARK: - Setup Assistant Menu Item

/// Skips Setup Assistant on a guest that is already activated. Enabled only
/// while vphoned reports that the guest will show it. See
/// `VPhoneGuestControlSetupAssistant.swift`.
extension VPhoneMenuController {
    func addSetupAssistantItem(to menu: NSMenu) {
        let item = makeItem("Skip Setup Assistant…", action: #selector(skipSetupAssistant), symbol: "forward.end")
        item.isEnabled = false
        skipSetupAssistantItem = item
        menu.addItem(item)
        control.observeSetupAssistantPending { [weak item] pending in
            item?.isEnabled = pending
        }
    }

    @objc func skipSetupAssistant() {
        VPhoneAlert.present(
            title: "Skip Setup Assistant?",
            message: "The guest marks setup as finished and restarts SpringBoard. Use this only on a guest that is already activated. Language, passcode, Apple Account and privacy settings keep their defaults.",
            style: .warning,
            buttons: ["Skip Setup", "Cancel"],
        ) { response in
            guard response == .alertFirstButtonReturn else { return }
            self.skipSetupAssistantItem?.isEnabled = false
            Task {
                do {
                    try await self.control.skipSetupAssistant()
                } catch {
                    print("[setup] skip failed: \(error)")
                    self.skipSetupAssistantItem?.isEnabled = self.control.isSetupAssistantPending
                    VPhoneAlert.present(
                        title: "Unable to Skip Setup Assistant",
                        message: "Check that the guest agent is connected, then try again.",
                        style: .warning,
                    )
                }
            }
        }
    }
}
