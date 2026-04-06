import AppKit
import SwiftUI

// Scrollable list of clipboard entries grouped by date.
// Implementation tracked in issues #11, #22, #23, #24, #25, #27, #28, #31, #33.
struct HistoryView: View {
    @Bindable var viewModel: HistoryViewModel
    @Environment(\.closePopover) private var closePopover

    /// Tracks whether the list is scrolled past the first item to show the scroll-to-top button.
    @State private var isScrolledDown = false
    /// Controls the alias-entry sheet for a selected entry.
    @State private var aliasTarget: ClipboardEntry? = nil
    /// The text the user is typing into the alias sheet.
    @State private var pendingAlias: String = ""

    private let topAnchorID = "historyListTop"

    var body: some View {
        if viewModel.groupedEntries.isEmpty {
            emptyState
        } else {
            HSplitView {
                listPanel
                if let entry = viewModel.selectedEntry {
                    EntryDetailView(entry: entry) {
                        viewModel.copy(entry: entry)
                        closePopover()
                    } onBack: {
                        viewModel.selectedId = nil
                    }
                    .frame(minWidth: 200)
                }
            }
        }
    }

    // MARK: - List panel

    private var listPanel: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollViewReader { proxy in
                List(selection: $viewModel.selectedId) {
                    // Invisible anchor at top for scroll-to-top
                    Color.clear
                        .frame(height: 0)
                        .id(topAnchorID)

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
                .frame(minWidth: 240, maxWidth: 320)
                .onKeyPress(.return) {
                    viewModel.copySelected()
                    closePopover()
                    return .handled
                }
                // Detect scroll position to toggle the scroll-to-top button.
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: ScrollOffsetPreference.self,
                                value: geo.frame(in: .named("historyScroll")).minY
                            )
                    }
                )
                .coordinateSpace(name: "historyScroll")
                .onPreferenceChange(ScrollOffsetPreference.self) { value in
                    withAnimation(Animations.list) {
                        isScrolledDown = value < -40
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if isScrolledDown {
                        Button {
                            withAnimation(Animations.list) {
                                proxy.scrollTo(topAnchorID, anchor: .top)
                            }
                        } label: {
                            Image(systemName: "chevron.up.circle.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                                .shadow(radius: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(Spacing.md)
                        .transition(.opacity.combined(with: .scale))
                        .accessibilityLabel(String(localized: "Scroll to top"))
                    }
                }
                // Re-classify All toolbar button
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button {
                            viewModel.reclassifyAll()
                        } label: {
                            Label(
                                String(localized: "Re-classify All"),
                                systemImage: "wand.and.stars"
                            )
                        }
                        .help(String(localized: "Re-classify all entries that have not been manually overridden"))
                    }
                }
            }
        }
        .sheet(item: $aliasTarget) { entry in
            aliasSheet(for: entry)
        }
    }

    // MARK: - Alias sheet

    private func aliasSheet(for entry: ClipboardEntry) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(String(localized: "Set Alias"))
                .font(.headline)

            Text(String(localized: "Enter a short alias for this clipboard entry."))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField(String(localized: "e.g. My API key"), text: $pendingAlias)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button(String(localized: "Cancel")) {
                    aliasTarget = nil
                }
                .keyboardShortcut(.cancelAction)

                Button(String(localized: "Save")) {
                    if let id = entry.id {
                        let value = pendingAlias.trimmingCharacters(in: .whitespaces)
                        viewModel.setAlias(id: id, alias: value.isEmpty ? nil : value)
                    }
                    aliasTarget = nil
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(Spacing.lg)
        .frame(width: 320)
        .onAppear {
            pendingAlias = entry.alias ?? ""
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

        // #23 — Alias
        Button(String(localized: "Set Alias…")) {
            aliasTarget = entry
        }
        if entry.alias != nil {
            Button(String(localized: "Clear Alias")) {
                guard let id = entry.id else { return }
                viewModel.setAlias(id: id, alias: nil)
            }
        }

        Divider()

        // #27 — Content type override submenu
        Menu(String(localized: "Set Content Type…")) {
            ForEach(ContentType.allCases, id: \.self) { type in
                Button(type.displayLabel) {
                    guard let id = entry.id else { return }
                    viewModel.setContentType(id: id, type: type)
                }
            }
        }

        // #28 — Re-classify individual entry
        Button(String(localized: "Re-classify")) {
            guard let id = entry.id, !entry.manualOverride else { return }
            viewModel.reclassifyEntry(entry: entry)
        }

        Divider()

        Button(String(localized: "Delete"), role: .destructive) {
            viewModel.delete(entry: entry)
        }
    }
}

// MARK: - Scroll offset preference key

private struct ScrollOffsetPreference: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - ContentType helpers for UI

private extension ContentType {
    var displayLabel: String {
        switch self {
        case .url:      return String(localized: "URL")
        case .email:    return String(localized: "Email")
        case .phone:    return String(localized: "Phone")
        case .color:    return String(localized: "Color")
        case .code:     return String(localized: "Code")
        case .text:     return String(localized: "Text")
        case .json:     return String(localized: "JSON")
        case .sql:      return String(localized: "SQL")
        case .shell:    return String(localized: "Shell")
        case .markdown: return String(localized: "Markdown")
        case .image:    return String(localized: "Image")
        }
    }
}
