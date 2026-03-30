import SwiftUI

// Root view rendered inside the menu bar popover.
// Hosts search bar + History/Collections tab switcher.
// Shell implementation tracked in issue #10.
struct MenuBarView: View {
    @State private var selectedTab: Tab = .history

    enum Tab { case history, collections }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar — issue #12
            // TODO: SearchBarView()

            // Content
            switch selectedTab {
            case .history:
                HistoryView()
            case .collections:
                CollectionsView()
            }

            // Tab bar
            Divider()
            HStack {
                tabButton("doc.on.doc", title: "History", tab: .history)
                tabButton("folder", title: "Collections", tab: .collections)
            }
            .padding(6)
        }
        .frame(width: 320)
        .background(.regularMaterial)
    }

    private func tabButton(_ symbol: String, title: String, tab: Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.system(size: 13))
                Text(title)
                    .font(.system(size: 11))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(selectedTab == tab ? Color.primary.opacity(0.1) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .foregroundStyle(selectedTab == tab ? .primary : .tertiary)
    }
}
