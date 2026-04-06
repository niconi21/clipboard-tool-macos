import SwiftUI

struct CollectionsView: View {
    @Bindable var viewModel: CollectionsViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.collections.isEmpty && !viewModel.isCreating {
                    emptyState
                } else {
                    collectionList
                }

                Divider()
                footer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationDestination(isPresented: $viewModel.isShowingSubcollections) {
                if let collection = viewModel.subcollectionsTarget {
                    SubcollectionsView(collection: collection)
                        .navigationBarBackButtonHidden(true)
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "square.stack")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(.secondary)

            Text(String(localized: "No collections yet"))
                .font(Typography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button {
                withAnimation(Animations.list) {
                    viewModel.isCreating = true
                }
            } label: {
                Label(String(localized: "New Collection"), systemImage: "plus")
                    .font(Typography.label)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Collection list + entries

    private var collectionList: some View {
        List {
            // Collections section
            Section {
                ForEach(viewModel.collections, id: \.id) { collection in
                    CollectionRowView(
                        collection: collection,
                        isSelected: viewModel.selectedCollection?.id == collection.id,
                        onSubcollectionsTap: {
                            viewModel.subcollectionsTarget = collection
                            viewModel.isShowingSubcollections = true
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(Animations.list) {
                            viewModel.select(collection)
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.deleteCollection(collection)
                        } label: {
                            Label(String(localized: "Delete Collection"), systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text(String(localized: "Collections"))
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }

            // Entries section — shown when a collection is selected
            if let selected = viewModel.selectedCollection {
                Section {
                    if viewModel.entriesInSelected.isEmpty {
                        HStack {
                            Spacer()
                            Text(String(localized: "No items in this collection"))
                                .font(Typography.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, Spacing.sm)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(viewModel.entriesInSelected) { entry in
                            EntryRowView(entry: entry)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        viewModel.removeEntry(entry, from: selected)
                                    } label: {
                                        Label(String(localized: "Remove from Collection"), systemImage: "minus.circle")
                                    }
                                }
                        }
                    }
                } header: {
                    Text(selected.name)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
        .animation(Animations.list, value: viewModel.selectedCollection?.id)
        .animation(Animations.list, value: viewModel.entriesInSelected.count)
    }

    // MARK: - Footer

    private var footer: some View {
        Group {
            if viewModel.isCreating {
                creationRow
            } else {
                newCollectionButton
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
    }

    private var newCollectionButton: some View {
        Button {
            withAnimation(Animations.list) {
                viewModel.isCreating = true
            }
        } label: {
            Label(String(localized: "New Collection"), systemImage: "plus")
                .font(Typography.label)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }

    private var creationRow: some View {
        HStack(spacing: Spacing.sm) {
            TextField(String(localized: "Collection name"), text: $viewModel.newCollectionName)
                .font(Typography.body)
                .textFieldStyle(.plain)
                .frame(maxWidth: .infinity)
                .onSubmit { viewModel.createCollection() }

            Button {
                viewModel.createCollection()
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.newCollectionName.trimmingCharacters(in: .whitespaces).isEmpty)
            .frame(minWidth: 44, minHeight: 44)

            Button {
                withAnimation(Animations.list) {
                    viewModel.isCreating = false
                    viewModel.newCollectionName = ""
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - CollectionRowView

private struct CollectionRowView: View {
    let collection: Collection
    let isSelected: Bool
    let onSubcollectionsTap: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: isSelected ? "folder.fill" : "folder")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .frame(width: 20)

            Text(collection.name)
                .font(Typography.body)
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)

            Button(action: onSubcollectionsTap) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.accentColor.opacity(0.7))
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel(String(localized: "View subcollections"))
            .help(String(localized: "View Subcollections"))
        }
        .padding(.vertical, Spacing.xs)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}
