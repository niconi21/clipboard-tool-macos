import SwiftUI

@main
struct ClipboardToolApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Boot database — runs migrations before any view loads
        _ = DatabaseManager.shared
    }

    var body: some Scene {
        // Settings window — opened via gear icon in the popover
        Settings {
            SettingsView()
        }
    }
}
