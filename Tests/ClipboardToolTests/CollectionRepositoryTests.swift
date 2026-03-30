import XCTest
import GRDB
@testable import ClipboardTool

final class CollectionRepositoryTests: XCTestCase {
    private var queue: DatabaseQueue!
    private var repository: CollectionRepository!
    private var entryRepository: ClipboardEntryRepository!

    override func setUp() async throws {
        queue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        Migrations.register(in: &migrator)
        try migrator.migrate(queue)
        repository = CollectionRepository(db: queue)
        entryRepository = ClipboardEntryRepository(db: queue)
    }

    // MARK: - Helpers

    private func makeEntry(content: String = "test content") async throws -> ClipboardEntry {
        let entry = ClipboardEntry(
            id: nil,
            content: content,
            contentType: .text,
            createdAt: Date(),
            isFavorite: false
        )
        return try await entryRepository.insert(entry)
    }

    // MARK: - Tests

    func testCreateCollection() async throws {
        let collection = try await repository.create(name: "Work")
        XCTAssertNotNil(collection.id)
        XCTAssertEqual(collection.name, "Work")
    }

    func testRenameCollection() async throws {
        let collection = try await repository.create(name: "Old Name")
        let id = try XCTUnwrap(collection.id)

        try await repository.rename(id: id, name: "New Name")

        let all = try await repository.fetchAll()
        let renamed = all.first { $0.id == id }
        XCTAssertEqual(renamed?.name, "New Name")
    }

    func testDeleteCollection() async throws {
        let collection = try await repository.create(name: "Temporary")
        let id = try XCTUnwrap(collection.id)

        try await repository.delete(id: id)

        let all = try await repository.fetchAll()
        XCTAssertTrue(all.filter { !$0.isBuiltin }.isEmpty)
    }

    func testDeleteCollectionCascadesToEntryCollections() async throws {
        let entry = try await makeEntry()
        let entryId = try XCTUnwrap(entry.id)

        let collection = try await repository.create(name: "Cascade Test")
        let collectionId = try XCTUnwrap(collection.id)

        try await repository.addEntry(entryId, to: collectionId)

        // Verify the entry is in the collection before deletion
        let entriesBefore = try await repository.fetchEntries(collectionId: collectionId)
        XCTAssertEqual(entriesBefore.count, 1)

        try await repository.delete(id: collectionId)

        // The collection is gone; the clipboard entry itself must still exist
        let remainingEntries = try await entryRepository.fetchRecent()
        XCTAssertEqual(remainingEntries.count, 1)

        // And no user-created collection should exist
        let allCollections = try await repository.fetchAll()
        XCTAssertTrue(allCollections.filter { !$0.isBuiltin }.isEmpty)
    }

    func testFetchAll() async throws {
        try await repository.create(name: "Alpha")
        try await repository.create(name: "Beta")
        try await repository.create(name: "Gamma")

        let all = try await repository.fetchAll()
        XCTAssertEqual(all.count, 4)
        // Must be ordered by created_at ASC — Favorites seeded first, then insertion order
        let userCreated = all.filter { !$0.isBuiltin }.map(\.name)
        XCTAssertEqual(userCreated, ["Alpha", "Beta", "Gamma"])
    }

    func testAddAndRemoveEntry() async throws {
        let entry = try await makeEntry(content: "Hello Swift")
        let entryId = try XCTUnwrap(entry.id)
        let collection = try await repository.create(name: "Snippets")
        let collectionId = try XCTUnwrap(collection.id)

        try await repository.addEntry(entryId, to: collectionId)

        let entries = try await repository.fetchEntries(collectionId: collectionId)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.content, "Hello Swift")

        try await repository.removeEntry(entryId, from: collectionId)

        let afterRemoval = try await repository.fetchEntries(collectionId: collectionId)
        XCTAssertTrue(afterRemoval.isEmpty)
    }

    func testFetchCollectionsForEntry() async throws {
        let entry = try await makeEntry()
        let entryId = try XCTUnwrap(entry.id)

        let collectionA = try await repository.create(name: "A")
        let collectionB = try await repository.create(name: "B")
        let collectionC = try await repository.create(name: "C")
        let idA = try XCTUnwrap(collectionA.id)
        let idB = try XCTUnwrap(collectionB.id)
        let idC = try XCTUnwrap(collectionC.id)

        try await repository.addEntry(entryId, to: idA)
        try await repository.addEntry(entryId, to: idB)
        // C is intentionally not linked

        let collections = try await repository.fetchCollections(forEntryId: entryId)
        XCTAssertEqual(collections.count, 2)
        let names = collections.map(\.name)
        XCTAssertTrue(names.contains("A"))
        XCTAssertTrue(names.contains("B"))
        XCTAssertFalse(names.contains("C"))
        _ = idC // silence unused warning
    }

    func testAddEntryDuplicateIsIdempotent() async throws {
        let entry = try await makeEntry()
        let entryId = try XCTUnwrap(entry.id)
        let collection = try await repository.create(name: "Dedup")
        let collectionId = try XCTUnwrap(collection.id)

        // Adding twice must not throw
        try await repository.addEntry(entryId, to: collectionId)
        try await repository.addEntry(entryId, to: collectionId)

        let entries = try await repository.fetchEntries(collectionId: collectionId)
        XCTAssertEqual(entries.count, 1)
    }
}
