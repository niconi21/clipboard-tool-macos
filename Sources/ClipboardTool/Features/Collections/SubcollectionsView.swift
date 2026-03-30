import SwiftUI
import AppKit

// MARK: - ViewModel

@Observable
final class SubcollectionsViewModel {
    private(set) var subcollections: [Subcollection] = []
    private(set) var isLoading = false

    private let repository: SubcollectionRepository
    let collection: Collection

    init(collection: Collection, repository: SubcollectionRepository = SubcollectionRepository()) {
        self.collection = collection
        self.repository = repository
    }

    func load() {
        Task { await refresh() }
    }

    @MainActor
    func refresh() async {
        guard let collectionId = collection.id else { return }
        subcollections = (try? await repository.fetchAll(for: collectionId)) ?? []
    }

    func addSubcollection(name: String) {
        guard let collectionId = collection.id else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        Task {
            try? await repository.create(name: trimmed, collectionId: collectionId)
            await refresh()
        }
    }

    func delete(_ subcollection: Subcollection) {
        guard let id = subcollection.id else { return }
        Task {
            try? await repository.delete(id: id)
            await refresh()
        }
    }

    func rename(_ subcollection: Subcollection, to newName: String) {
        guard let id = subcollection.id else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        Task {
            try? await repository.rename(id: id, name: trimmed)
            await refresh()
        }
    }
}

// MARK: - View

struct SubcollectionsView: View {
    @State private var viewModel: SubcollectionsViewModel
    @Environment(\.dismiss) private var dismiss

    init(collection: Collection) {
        _viewModel = State(initialValue: SubcollectionsViewModel(collection: collection))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if viewModel.subcollections.isEmpty {
                emptyState
            } else {
                subcollectionList
            }

            Divider()
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { viewModel.load() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 32, minHeight: 32)

            Text(viewModel.collection.name)
                .font(Typography.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(.secondary)

            Text(String(localized: "No subcollections yet"))
                .font(Typography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button {
                promptForSubcollectionName()
            } label: {
                Label(String(localized: "New Subcollection"), systemImage: "plus")
                    .font(Typography.label)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - List

    private var subcollectionList: some View {
        List {
            ForEach(viewModel.subcollections, id: \.id) { subcollection in
                SubcollectionRowView(subcollection: subcollection)
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.delete(subcollection)
                        } label: {
                            Label(String(localized: "Delete"), systemImage: "trash")
                        }
                    }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    viewModel.delete(viewModel.subcollections[index])
                }
            }
        }
        .listStyle(.sidebar)
        .animation(Animations.list, value: viewModel.subcollections.count)
    }

    // MARK: - Footer

    private var footer: some View {
        Button {
            promptForSubcollectionName()
        } label: {
            Label(String(localized: "New Subcollection"), systemImage: "plus")
                .font(Typography.label)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - NSAlert prompt

    private func promptForSubcollectionName() {
        let alert = NSAlert()
        alert.messageText = String(localized: "New Subcollection")
        alert.informativeText = String(localized: "Enter a name for the subcollection.")
        alert.addButton(withTitle: String(localized: "Create"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        textField.placeholderString = String(localized: "Subcollection name")
        alert.accessoryView = textField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            viewModel.addSubcollection(name: textField.stringValue)
        }
    }
}

// MARK: - SubcollectionRowView

private struct SubcollectionRowView: View {
    let subcollection: Subcollection

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: subcollection.isDefault ? "folder.fill.badge.gearshape" : "folder")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(subcollection.name)
                .font(Typography.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)

            if subcollection.isDefault {
                Text(String(localized: "Default"))
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Spacing.xs)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}
