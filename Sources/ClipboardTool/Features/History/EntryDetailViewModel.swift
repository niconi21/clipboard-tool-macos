import Foundation
import GRDB

@Observable
final class EntryDetailViewModel {
    private(set) var collections: [Collection] = []
    private(set) var allCollections: [Collection] = []
    private let collectionRepo: CollectionRepository

    init(collectionRepo: CollectionRepository = CollectionRepository()) {
        self.collectionRepo = collectionRepo
    }

    func load(for entryId: Int64) async {
        async let mine = (try? await collectionRepo.fetchCollections(forEntryId: entryId)) ?? []
        async let all = (try? await collectionRepo.fetchAll()) ?? []
        (collections, allCollections) = await (mine, all)
    }

    func addToCollection(entryId: Int64, collectionId: Int64) async {
        try? await collectionRepo.addEntry(entryId, to: collectionId)
        await load(for: entryId)
    }

    func removeFromCollection(entryId: Int64, collectionId: Int64) async {
        try? await collectionRepo.removeEntry(entryId, from: collectionId)
        await load(for: entryId)
    }
}
