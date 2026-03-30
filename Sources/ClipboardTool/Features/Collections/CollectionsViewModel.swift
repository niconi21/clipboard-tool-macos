import Foundation

@Observable
final class CollectionsViewModel {
    private(set) var collections: [Collection] = []
    private(set) var selectedCollection: Collection? = nil
    private(set) var entriesInSelected: [ClipboardEntry] = []
    var newCollectionName: String = ""
    var isCreating: Bool = false
    var subcollectionsTarget: Collection? = nil
    var isShowingSubcollections: Bool = false

    private let repository = CollectionRepository()

    func load() {
        Task { await refresh() }
    }

    @MainActor
    func refresh() async {
        collections = (try? await repository.fetchAll()) ?? []
        if let selected = selectedCollection,
           let updated = collections.first(where: { $0.id == selected.id }) {
            selectedCollection = updated
            await loadEntries(for: updated)
        } else {
            entriesInSelected = []
        }
    }

    func select(_ collection: Collection) {
        selectedCollection = collection
        Task { await loadEntries(for: collection) }
    }

    func createCollection() {
        let name = newCollectionName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        Task {
            try? await repository.create(name: name)
            await MainActor.run {
                newCollectionName = ""
                isCreating = false
            }
            await refresh()
        }
    }

    func deleteCollection(_ collection: Collection) {
        guard let id = collection.id else { return }
        Task {
            try? await repository.delete(id: id)
            await MainActor.run {
                if selectedCollection?.id == id {
                    selectedCollection = nil
                    entriesInSelected = []
                }
            }
            await refresh()
        }
    }

    func removeEntry(_ entry: ClipboardEntry, from collection: Collection) {
        guard let entryId = entry.id, let collectionId = collection.id else { return }
        Task {
            try? await repository.removeEntry(entryId, from: collectionId)
            await refresh()
        }
    }

    @MainActor
    private func loadEntries(for collection: Collection) async {
        guard let id = collection.id else { return }
        entriesInSelected = (try? await repository.fetchEntries(collectionId: id)) ?? []
    }
}
