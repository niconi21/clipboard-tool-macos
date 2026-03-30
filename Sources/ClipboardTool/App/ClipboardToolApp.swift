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
        // Onboarding is shown on first launch by AppDelegate when
        // UserDefaults.standard.bool(forKey: "onboardingCompleted") is false.
        // AppDelegate sets the key to true when the user completes the flow.
    }
}
