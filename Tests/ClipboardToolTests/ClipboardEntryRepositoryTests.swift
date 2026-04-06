import CryptoKit
import XCTest
import GRDB
@testable import ClipboardTool

final class ClipboardEntryRepositoryTests: XCTestCase {
    private var queue: DatabaseQueue!
    private var repository: ClipboardEntryRepository!

    override func setUp() async throws {
        // In-memory DB for tests — isolated, no disk I/O
        queue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        Migrations.register(in: &migrator)
        try migrator.migrate(queue)
        repository = ClipboardEntryRepository(db: queue)
    }

    func testInsertAndFetch() async throws {
        let entry = ClipboardEntry(id: nil, content: "Hello world",
                                   contentType: .text, createdAt: .now, isFavorite: false)
        let inserted = try await repository.insert(entry)
        XCTAssertNotNil(inserted.id)

        let results = try await repository.fetchRecent()
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.content, "Hello world")
    }

    func testDelete() async throws {
        let entry = ClipboardEntry(id: nil, content: "Delete me",
                                   contentType: .text, createdAt: .now, isFavorite: false)
        let inserted = try await repository.insert(entry)
        try await repository.delete(id: inserted.id!)

        let results = try await repository.fetchRecent()
        XCTAssertTrue(results.isEmpty)
    }

    func testDeleteAll() async throws {
        for i in 1...3 {
            let e = ClipboardEntry(id: nil, content: "Item \(i)",
                                   contentType: .text, createdAt: .now, isFavorite: false)
            try await repository.insert(e)
        }
        try await repository.deleteAll()
        let total = try await repository.count()
        XCTAssertEqual(total, 0)
    }

    func testToggleFavorite() async throws {
        let entry = ClipboardEntry(id: nil, content: "Star me",
                                   contentType: .text, createdAt: .now, isFavorite: false)
        let inserted = try await repository.insert(entry)
        try await repository.toggleFavorite(id: inserted.id!)

        let favorites = try await repository.fetchFavorites()
        XCTAssertEqual(favorites.count, 1)
    }

    func testSearch() async throws {
        let entries = [
            ClipboardEntry(id: nil, content: "https://github.com",
                           contentType: .url, createdAt: .now, isFavorite: false),
            ClipboardEntry(id: nil, content: "Hello swift world",
                           contentType: .text, createdAt: .now, isFavorite: false),
        ]
        for e in entries { try await repository.insert(e) }

        let results = try await repository.search(query: "swift")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.content, "Hello swift world")
    }

    func testExists() async throws {
        let entry = ClipboardEntry(id: nil, content: "Unique content",
                                   contentType: .text, createdAt: .now, isFavorite: false)
        try await repository.insert(entry)

        let hashOf: (String) -> String = { content in
            SHA256.hash(data: Data(content.utf8)).map { String(format: "%02x", $0) }.joined()
        }
        let exists = try await repository.exists(contentHash: hashOf("Unique content"))
        let notExists = try await repository.exists(contentHash: hashOf("Not there"))
        XCTAssertTrue(exists)
        XCTAssertFalse(notExists)
    }

    func testPagination() async throws {
        for i in 1...10 {
            let e = ClipboardEntry(id: nil, content: "Item \(i)",
                                   contentType: .text, createdAt: .now, isFavorite: false)
            try await repository.insert(e)
        }
        let page1 = try await repository.fetchRecent(limit: 5, offset: 0)
        let page2 = try await repository.fetchRecent(limit: 5, offset: 5)
        XCTAssertEqual(page1.count, 5)
        XCTAssertEqual(page2.count, 5)
        XCTAssertNotEqual(page1.first?.content, page2.first?.content)
    }

    // MARK: - updateAlias (#23)

    func testUpdateAlias() async throws {
        let inserted = try await repository.insert(
            ClipboardEntry(id: nil, content: "alias test", contentType: .text,
                           createdAt: .now, isFavorite: false)
        )
        try await repository.updateAlias(id: inserted.id!, alias: "My Label")

        let results = try await repository.fetchRecent()
        XCTAssertEqual(results.first?.alias, "My Label")
    }

    func testUpdateAliasClear() async throws {
        let inserted = try await repository.insert(
            ClipboardEntry(id: nil, content: "alias clear test", contentType: .text,
                           createdAt: .now, isFavorite: false, alias: "Old")
        )
        try await repository.updateAlias(id: inserted.id!, alias: nil)

        let results = try await repository.fetchRecent()
        XCTAssertNil(results.first?.alias)
    }

    // MARK: - updateContentType (#27)

    func testUpdateContentTypeSetsManualOverride() async throws {
        let inserted = try await repository.insert(
            ClipboardEntry(id: nil, content: "https://example.com", contentType: .url,
                           createdAt: .now, isFavorite: false)
        )
        XCTAssertFalse(inserted.manualOverride)

        try await repository.updateContentType(id: inserted.id!, contentType: .text)

        let results = try await repository.fetchRecent()
        XCTAssertEqual(results.first?.contentType, .text)
        XCTAssertTrue(results.first?.manualOverride ?? false)
    }

    // MARK: - clearManualOverride (#28)

    func testClearManualOverride() async throws {
        let inserted = try await repository.insert(
            ClipboardEntry(id: nil, content: "some text", contentType: .text,
                           createdAt: .now, isFavorite: false)
        )
        try await repository.updateContentType(id: inserted.id!, contentType: .code)
        try await repository.clearManualOverride(id: inserted.id!)

        let results = try await repository.fetchRecent()
        XCTAssertFalse(results.first?.manualOverride ?? true)
    }

    // MARK: - fetchAll (#28)

    func testFetchAllReturnsAllEntries() async throws {
        for i in 1...5 {
            let e = ClipboardEntry(id: nil, content: "FetchAll \(i)",
                                   contentType: .text, createdAt: .now, isFavorite: false)
            try await repository.insert(e)
        }
        let all = try await repository.fetchAll()
        XCTAssertEqual(all.count, 5)
    }
}
