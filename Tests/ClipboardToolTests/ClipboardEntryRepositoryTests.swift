import XCTest
import GRDB
@testable import ClipboardTool

final class ClipboardEntryRepositoryTests: XCTestCase {
    private var pool: DatabasePool!
    private var repository: ClipboardEntryRepository!

    override func setUp() async throws {
        // In-memory DB for tests — isolated, no disk I/O
        pool = try DatabasePool()
        var migrator = DatabaseMigrator()
        Migrations.register(in: &migrator)
        try migrator.migrate(pool)
        repository = ClipboardEntryRepository(pool: pool)
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
        XCTAssertEqual(try await repository.count(), 0)
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

        XCTAssertTrue(try await repository.exists(content: "Unique content"))
        XCTAssertFalse(try await repository.exists(content: "Not there"))
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
}
