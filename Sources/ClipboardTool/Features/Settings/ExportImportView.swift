import SwiftUI
import AppKit

// View with Export and Import buttons for user configuration.
// Uses NSSavePanel / NSOpenPanel with callback-based API to avoid blocking the main actor.
@MainActor
struct ExportImportView: View {
    @State private var viewModel = ExportImportViewModel()

    var body: some View {
        Form {
            Section {
                LabeledContent(String(localized: "Export Configuration")) {
                    Button(String(localized: "Export…")) {
                        exportConfiguration()
                    }
                }

                LabeledContent(String(localized: "Import Configuration")) {
                    Button(String(localized: "Import…")) {
                        importConfiguration()
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
            viewModel.alertTitle,
            isPresented: $viewModel.showAlert
        ) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage)
        }
    }

    // MARK: - Private

    private func exportConfiguration() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "clipboard-tool-config.json"
        panel.title = String(localized: "Export Configuration")
        panel.begin { [weak panel] response in
            guard response == .OK, let url = panel?.url else { return }
            Task { await viewModel.export(to: url) }
        }
    }

    private func importConfiguration() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = String(localized: "Import Configuration")
        panel.begin { [weak panel] response in
            guard response == .OK, let url = panel?.url else { return }
            Task { await viewModel.import(from: url) }
        }
    }
}
