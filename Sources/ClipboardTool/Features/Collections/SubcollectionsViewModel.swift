import Foundation

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
        Task { [weak self] in
            guard let self else { return }
            await refresh()
        }
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
        Task { [weak self] in
            guard let self else { return }
            try? await repository.create(name: trimmed, collectionId: collectionId)
            await refresh()
        }
    }

    func delete(_ subcollection: Subcollection) {
        guard let id = subcollection.id else { return }
        Task { [weak self] in
            guard let self else { return }
            try? await repository.delete(id: id)
            await refresh()
        }
    }

    func rename(_ subcollection: Subcollection, to newName: String) {
        guard let id = subcollection.id else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            try? await repository.rename(id: id, name: trimmed)
            await refresh()
        }
    }
}
