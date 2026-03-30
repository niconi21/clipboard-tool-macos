import SwiftUI
import AppKit

// View with Export and Import buttons for user configuration.
// Uses NSSavePanel / NSOpenPanel to pick file destinations — must run on @MainActor.
@MainActor
struct ExportImportView: View {
    @State private var alertMessage: String = ""
    @State private var showAlert = false
    @State private var isSuccess = false

    private let manager = ExportImportManager()

    var body: some View {
        Form {
            Section {
                LabeledContent(String(localized: "Export Configuration")) {
                    Button(String(localized: "Export…")) {
                        Task { await exportConfiguration() }
                    }
                }

                LabeledContent(String(localized: "Import Configuration")) {
                    Button(String(localized: "Import…")) {
                        Task { await importConfiguration() }
                    }
                }
            } header: {
                Text(String(localized: "User Configuration"))
            } footer: {
                Text(String(localized: "Exports collections, rules, and settings. Clipboard history is not included."))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(Spacing.lg)
        .alert(
            isSuccess
                ? String(localized: "Success")
                : String(localized: "Error"),
            isPresented: $showAlert
        ) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Private

    private func exportConfiguration() async {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "clipboard-tool-config.json"
        panel.title = String(localized: "Export Configuration")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try await manager.export(db: DatabaseManager.shared.pool)
            try data.write(to: url, options: .atomic)
            isSuccess = true
            alertMessage = String(localized: "Configuration exported successfully.")
        } catch {
            isSuccess = false
            alertMessage = error.localizedDescription
        }
        showAlert = true
    }

    private func importConfiguration() async {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = String(localized: "Import Configuration")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            try await manager.import(data: data, db: DatabaseManager.shared.pool)
            isSuccess = true
            alertMessage = String(localized: "Configuration imported successfully.")
        } catch {
            isSuccess = false
            alertMessage = error.localizedDescription
        }
        showAlert = true
    }
}
