import SwiftUI

// Root view rendered inside the menu bar popover.
// Hosts search bar + History/Collections tab switcher.
struct MenuBarView: View {
    @State private var selectedTab: Tab = .history
    @State private var historyViewModel = HistoryViewModel()
    @State private var collectionsViewModel = CollectionsViewModel()
    @Environment(\.openSettings) private var openSettings

    enum Tab { case history, collections }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar with title and gear button
            HStack {
                Text(String(localized: "Clipboard Tool"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    if historyViewModel.isPaused {
                        historyViewModel.resumeMonitoring()
                    } else {
                        historyViewModel.pauseMonitoring()
                    }
                } label: {
                    Image(systemName: historyViewModel.isPaused ? "play.circle" : "pause.circle")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(historyViewModel.isPaused
                      ? String(localized: "Resume monitoring")
                      : String(localized: "Pause monitoring"))
                .accessibilityLabel(historyViewModel.isPaused
                      ? String(localized: "Resume monitoring")
                      : String(localized: "Pause monitoring"))
                Button {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(String(localized: "Settings"))
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)

            // Search bar — only visible on History tab
            if selectedTab == .history {
                let bindable = Bindable(historyViewModel)
                SearchBarView(text: bindable.searchText)
                Divider()
            }

            // Content
            ZStack {
                switch selectedTab {
                case .history:
                    HistoryView(viewModel: historyViewModel)
                        .transition(.opacity)
                case .collections:
                    CollectionsView(viewModel: collectionsViewModel)
                        .transition(.opacity)
                        .onAppear { collectionsViewModel.load() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(Animations.list, value: selectedTab)

            // Tab bar
            Divider()
            HStack(spacing: 0) {
                tabButton("doc.on.doc", label: String(localized: "History"), tab: .history)
                tabButton("folder", label: String(localized: "Collections"), tab: .collections)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
        }
        .frame(width: 320)
        .background(.regularMaterial)
        .onAppear { historyViewModel.start() }
        .onDisappear { historyViewModel.stop() }
    }

    @ViewBuilder
    private func tabButton(_ symbol: String, label: String, tab: Tab) -> some View {
        let isActive = selectedTab == tab

        Button {
            withAnimation(Animations.list) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: Spacing.xs) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(isActive ? Color.accentColor : .secondary)

                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(isActive ? Color.accentColor : .secondary)

                // Active underline indicator
                Capsule()
                    .fill(isActive ? Color.accentColor : Color.clear)
                    .frame(width: 16, height: 2)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(Animations.list, value: selectedTab)
    }
}
