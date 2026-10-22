import AppKit
import Foundation
import Observation

@Observable
@MainActor
class VPhoneKeychainBrowserModel {
    let control: VPhoneGuestControl

    var items: [VPhoneKeychainItem] = []
    var isLoading = false
    var error: String?
    var diagnostics: [String] = []
    var searchText = ""
    var selection = Set<VPhoneKeychainItem.ID>()
    var sortOrder = [KeyPathComparator(\VPhoneKeychainItem.displayName)]
    var filterClass: String?
    var showDiagnostics = false
    var editing: EditingValue?
    var pendingDeletion: Set<VPhoneKeychainItem.ID>?

    init(control: VPhoneGuestControl) {
        self.control = control
    }

    // MARK: - Computed

    var filteredItems: [VPhoneKeychainItem] {
        var list = items
        if let filterClass {
            list = list.filter { $0.itemClass == filterClass }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            list = list.filter {
                $0.account.lowercased().contains(query)
                    || $0.service.lowercased().contains(query)
                    || $0.label.lowercased().contains(query)
                    || $0.accessGroup.lowercased().contains(query)
                    || $0.server.lowercased().contains(query)
                    || $0.protection.lowercased().contains(query)
                    || $0.value.lowercased().contains(query)
            }
        }
        return list.sorted(using: sortOrder)
    }

    var statusText: String {
        let count = filteredItems.count
        let total = items.count
        if count != total {
            return VPhoneLocalization.format("%@/%@ items", String(count), String(total))
        }
        if count == 0, !diagnostics.isEmpty {
            return VPhoneLocalization.text("No items")
        }
        return count == 1
            ? VPhoneLocalization.text("1 item")
            : VPhoneLocalization.format("%@ items", String(count))
    }

    static let classFilters: [(label: String, value: String?)] = [
        ("All", nil),
        ("Passwords", "genp"),
        ("Internet", "inet"),
        ("Certificates", "cert"),
        ("Keys", "keys"),
    ]

    func copyRows(ids: Set<VPhoneKeychainItem.ID>) {
        let selected = filteredItems.filter { ids.contains($0.id) }
        guard !selected.isEmpty else { return }
        let header = "Class\tAccount\tService\tAccess Group\tProtection\tValue"
        let rows = selected.map { item in
            "\(item.displayClass)\t\(item.account)\t\(item.service)\t\(item.accessGroup)\t\(item.protection)\t\(item.displayValue)"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(([header] + rows).joined(separator: "\n"), forType: .string)
    }

    // MARK: - Editing

    /// The rows the guest can act on: the ones Security.framework answered for.
    func editableItems(ids: Set<VPhoneKeychainItem.ID>) -> [VPhoneKeychainItem] {
        filteredItems.filter { ids.contains($0.id) && $0.isAccessible }
    }

    var canEdit: Bool {
        control.guestCapabilities.contains("keychain_edit")
    }

    func reveal(ids: Set<VPhoneKeychainItem.ID>) async {
        for item in editableItems(ids: ids) {
            do {
                let value = try await control.keychainValue(of: item.identity)
                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    items[index].value = value
                }
            } catch {
                self.error = VPhoneLocalization.text("Unable to read the keychain item. Try again.")
                print("[keychain] read failed: \(error)")
                return
            }
        }
    }

    func beginEditing(ids: Set<VPhoneKeychainItem.ID>) async {
        guard let item = editableItems(ids: ids).first else { return }
        do {
            editing = try await EditingValue(item: item, value: control.keychainValue(of: item.identity))
        } catch {
            self.error = VPhoneLocalization.text("Unable to read the keychain item. Try again.")
            print("[keychain] read failed: \(error)")
        }
    }

    func commitEditing() async {
        guard let editing else { return }
        self.editing = nil
        do {
            try await control.updateKeychainItem(editing.item.identity, value: editing.value)
            await refresh()
        } catch {
            self.error = VPhoneLocalization.text("Unable to update the keychain item. Try again.")
            print("[keychain] update failed: \(error)")
        }
    }

    func delete(ids: Set<VPhoneKeychainItem.ID>) async {
        for item in editableItems(ids: ids) {
            do {
                try await control.deleteKeychainItem(item.identity)
            } catch {
                self.error = VPhoneLocalization.text("Unable to delete the keychain item. Try again.")
                print("[keychain] delete failed: \(error)")
                break
            }
        }
        selection.removeAll()
        await refresh()
    }

    struct EditingValue: Identifiable {
        let item: VPhoneKeychainItem
        var value: String

        var id: VPhoneKeychainItem.ID {
            item.id
        }
    }

    // MARK: - Actions

    func addTestItem() async {
        do {
            try await control.addKeychainItem()
            print("[keychain] test item added, refreshing...")
            await refresh()
        } catch {
            self.error = VPhoneLocalization.text("Unable to add the keychain item. Try again.")
            print("[keychain] add failed: \(error)")
        }
    }

    func removeTestItem() async {
        do {
            _ = try await control.deleteKeychainItem(account: "vphone-test", service: "vphone")
            await refresh()
        } catch {
            self.error = VPhoneLocalization.text("Unable to remove the test keychain item. Try again.")
            print("[keychain] remove failed: \(error)")
        }
    }

    // MARK: - Refresh

    func refresh() async {
        guard control.isConnected else {
            error = VPhoneLocalization.text("The guest agent is not connected. Wait for it to connect, then try again.")
            return
        }
        isLoading = true
        error = nil
        do {
            let result = try await control.listKeychainItems()
            items = result.items.enumerated().compactMap { VPhoneKeychainItem(index: $0.offset, entry: $0.element) }
            diagnostics = result.diagnostics
            if items.isEmpty, !diagnostics.isEmpty {
                print("[keychain] 0 items, diag: \(diagnostics)")
            }
        } catch {
            self.error = VPhoneLocalization.text(
                "Unable to load keychain items. Check that the guest agent is connected, then try again.",
            )
            items = []
        }
        isLoading = false
    }
}
