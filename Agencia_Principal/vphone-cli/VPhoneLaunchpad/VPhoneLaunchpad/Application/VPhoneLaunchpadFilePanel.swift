import AppKit

extension NSSavePanel {
    /// Shows the panel as a sheet on the front window, which is the form
    /// sheet itself when one is open, and calls `choose` with the pick.
    /// Without a window it falls back to a modal panel.
    func present(_ choose: @escaping @MainActor (URL) -> Void) {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else {
            if runModal() == .OK, let url {
                choose(url)
            }
            return
        }
        beginSheetModal(for: window) { [self] response in
            if response == .OK, let url {
                MainActor.assumeIsolated { choose(url) }
            }
        }
    }
}
