import SwiftUI

struct SubcollectionsView: View {
    @State private var viewModel: SubcollectionsViewModel
    @State private var isAddingSubcollection = false
    @State private var newSubcollectionName = ""
    @Environment(\.dismiss) private var dismiss

    init(collection: Collection) {
        _viewModel = State(initialValue: SubcollectionsViewModel(collection: collection))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if viewModel.subcollections.isEmpty && !isAddingSubcollection {
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
                withAnimation(Animations.list) {
                    isAddingSubcollection = true
                }
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
        Group {
            if isAddingSubcollection {
                creationRow
            } else {
                newSubcollectionButton
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
    }

    private var newSubcollectionButton: some View {
        Button {
            withAnimation(Animations.list) {
                isAddingSubcollection = true
            }
        } label: {
            Label(String(localized: "New Subcollection"), systemImage: "plus")
                .font(Typography.label)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }

    private var creationRow: some View {
        HStack(spacing: Spacing.sm) {
            TextField(String(localized: "Subcollection name"), text: $newSubcollectionName)
                .font(Typography.body)
                .textFieldStyle(.plain)
                .frame(maxWidth: .infinity)
                .onSubmit { confirmAdd() }

            Button {
                confirmAdd()
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(newSubcollectionName.trimmingCharacters(in: .whitespaces).isEmpty)
            .frame(minWidth: 44, minHeight: 44)

            Button {
                withAnimation(Animations.list) {
                    isAddingSubcollection = false
                    newSubcollectionName = ""
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

    private func confirmAdd() {
        viewModel.addSubcollection(name: newSubcollectionName)
        newSubcollectionName = ""
        withAnimation(Animations.list) {
            isAddingSubcollection = false
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
