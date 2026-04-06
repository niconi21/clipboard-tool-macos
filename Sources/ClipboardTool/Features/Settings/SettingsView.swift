import SwiftUI
import KeyboardShortcuts

// Native macOS Settings window with tab navigation.
// Opened via the gear button in MenuBarView.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label(String(localized: "General"), systemImage: "gear") }
            AppearanceSettingsView()
                .tabItem { Label(String(localized: "Appearance"), systemImage: "paintbrush") }
            ShortcutsSettingsView()
                .tabItem { Label(String(localized: "Shortcuts"), systemImage: "keyboard") }
            StorageSettingsView()
                .tabItem { Label(String(localized: "Storage"), systemImage: "cylinder") }
            ExportImportView()
                .tabItem { Label(String(localized: "Data"), systemImage: "arrow.up.arrow.down") }
            AboutSettingsView()
                .tabItem { Label(String(localized: "About"), systemImage: "info.circle") }
        }
        .frame(width: 520, height: 360)
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    @State private var autoStart = AutoStartManager()
    @State private var launchAtLogin: Bool = AutoStartManager().isEnabled
    @AppStorage("historyLimit") private var historyLimit: Int = 100
    @AppStorage("appLanguage") private var appLanguage: String = "en"
    @State private var showRestartAlert = false

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Launch at login"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try autoStart.enable()
                            } else {
                                try autoStart.disable()
                            }
                        } catch {
                            // Expected to fail in dev without signing — swallow silently
                        }
                    }
            }

            Section {
                Picker(String(localized: "History limit"), selection: $historyLimit) {
                    Text("50").tag(50)
                    Text("100").tag(100)
                    Text("500").tag(500)
                    Text("1000").tag(1000)
                    Text(String(localized: "Unlimited")).tag(0)
                }
                .pickerStyle(.menu)
            }

            Section {
                Picker(String(localized: "Language"), selection: $appLanguage) {
                    Text("English").tag("en")
                    Text("Español (MX)").tag("es-MX")
                }
                .pickerStyle(.menu)
                .onChange(of: appLanguage) { _, newValue in
                    UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
                    showRestartAlert = true
                }
            }
        }
        .formStyle(.grouped)
        .padding(Spacing.lg)
        .alert(String(localized: "Language changed"), isPresented: $showRestartAlert) {
            Button(String(localized: "Restart now")) { NSApp.relaunch() }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "Restart the app to apply the new language."))
        }
    }
}

// MARK: - Appearance

private struct AppearanceSettingsView: View {
    @AppStorage("appTheme") private var appTheme: String = "system"

    var body: some View {
        Form {
            Section {
                Picker(String(localized: "Theme"), selection: $appTheme) {
                    Text(String(localized: "System")).tag("system")
                    Text(String(localized: "Light")).tag("light")
                    Text(String(localized: "Dark")).tag("dark")
                }
                .pickerStyle(.segmented)
                .onChange(of: appTheme) { _, newValue in
                    switch newValue {
                    case "light":
                        NSApp.appearance = NSAppearance(named: .aqua)
                    case "dark":
                        NSApp.appearance = NSAppearance(named: .darkAqua)
                    default:
                        NSApp.appearance = nil
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(Spacing.lg)
    }
}

// MARK: - Shortcuts

private struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section {
                LabeledContent(String(localized: "Toggle clipboard")) {
                    KeyboardShortcuts.Recorder(for: .togglePopover)
                }
            }
        }
        .formStyle(.grouped)
        .padding(Spacing.lg)
    }
}

// MARK: - Storage

private struct StorageSettingsView: View {
    @State private var viewModel = StorageSettingsViewModel()
    @State private var showingClearConfirmation = false

    var body: some View {
        Form {
            Section {
                LabeledContent(String(localized: "Database")) {
                    Text(viewModel.dbPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Section {
                Button(String(localized: "Clear History"), role: .destructive) {
                    showingClearConfirmation = true
                }
                .alert(
                    String(localized: "Clear History"),
                    isPresented: $showingClearConfirmation
                ) {
                    Button(String(localized: "Clear"), role: .destructive) {
                        Task {
                            await viewModel.clearHistory()
                        }
                    }
                    Button(String(localized: "Cancel"), role: .cancel) {}
                } message: {
                    Text(String(localized: "This will permanently delete all clipboard history. This action cannot be undone."))
                }
            }
        }
        .formStyle(.grouped)
        .padding(Spacing.lg)
        .alert(
            String(localized: "Error"),
            isPresented: $viewModel.showClearError
        ) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.clearErrorMessage)
        }
    }
}

// MARK: - About

private struct AboutSettingsView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            VStack(spacing: Spacing.sm) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Color.accentColor)

                Text(String(localized: "Clipboard Tool"))
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(String(localized: "Version \(appVersion)"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(String(localized: "Local clipboard manager. No cloud sync, no telemetry."))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Link(
                String(localized: "View on GitHub"),
                destination: URL(string: "https://github.com/niconi21/clipboard-tool-macos")!
            )
            .font(.body)

            Spacer()
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
    }
}
