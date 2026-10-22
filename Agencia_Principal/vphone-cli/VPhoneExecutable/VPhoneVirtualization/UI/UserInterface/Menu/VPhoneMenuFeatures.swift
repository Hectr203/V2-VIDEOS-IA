import AppKit

// MARK: - Features Menu

/// Host sensor controls, with the motion panels grouped in their own submenu.
extension VPhoneMenuController {
    func buildFeaturesMenu() -> NSMenuItem {
        let item = NSMenuItem(title: "Features", action: nil, keyEquivalent: "")
        let menu = NSMenu(title: "Features")
        menu.autoenablesItems = false
        for section in [buildLocationSubmenu(), buildBatterySubmenu(), buildCameraSubmenu()] {
            if menu.numberOfItems > 0 {
                menu.addItem(NSMenuItem.separator())
            }
            menu.addItem(NSMenuItem.sectionHeader(title: section.title))
            // Move, not copy: the controller keeps references to these items.
            let items = section.submenu?.items ?? []
            section.submenu?.removeAllItems()
            for child in items {
                menu.addItem(child)
            }
        }
        menu.addItem(NSMenuItem.separator())
        menu.addItem(buildMotionSensorsMenu())
        item.submenu = menu
        return item
    }
}
