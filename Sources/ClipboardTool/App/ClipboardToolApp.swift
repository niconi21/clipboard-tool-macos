import SwiftUI

@main
struct ClipboardToolApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings window — opened via gear icon in the popover
        Settings {
            SettingsView()
        }
    }
}
