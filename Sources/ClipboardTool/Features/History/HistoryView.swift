import SwiftUI

// Scrollable list of clipboard entries grouped by date.
// Implementation tracked in issue #11.
struct HistoryView: View {
    @Bindable var viewModel: HistoryViewModel
    @Environment(\.closePopover) private var closePopover

    var body: some View {
        if viewModel.groupedEntries.isEmpty {
            emptyState
        } else {
            List(selection: $viewModel.selectedId) {
                ForEach(viewModel.groupedEntries, id: \.label) { group in
                    Section(group.label) {
                        ForEach(group.entries) { entry in
                            EntryRowView(entry: entry)
                                .tag(entry.id)
                                .contextMenu { contextMenu(for: entry) }
                                .onTapGesture {
                                    viewModel.copy(entry: entry)
                                    closePopover()
                                }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .onKeyPress(.return) {
                viewModel.copySelected()
                closePopover()
                return .handled
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "clock")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(.secondary)

            Text(String(localized: "Your clipboard history will appear here"))
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Context menu

    @ViewBuilder
    private func contextMenu(for entry: ClipboardEntry) -> some View {
        Button(String(localized: "Copy")) {
            viewModel.copy(entry: entry)
            closePopover()
        }
        Divider()
        Button(entry.isFavorite ? String(localized: "Unfavorite") : String(localized: "Favorite")) {
            viewModel.toggleFavorite(entry: entry)
        }
        Divider()
        Button(String(localized: "Delete"), role: .destructive) {
            viewModel.delete(entry: entry)
        }
    }
}
