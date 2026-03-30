import XCTest
import GRDB
@testable import ClipboardTool

final class CollectionRuleEngineTests: XCTestCase {

    private var queue: DatabaseQueue!
    private var collectionRepo: CollectionRepository!
    private var entryRepo: ClipboardEntryRepository!
    private var engine: CollectionRuleEngine!

    override func setUp() async throws {
        queue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        Migrations.register(in: &migrator)
        try migrator.migrate(queue)
        collectionRepo = CollectionRepository(db: queue)
        entryRepo = ClipboardEntryRepository(db: queue)
        engine = CollectionRuleEngine()
    }

    // MARK: - Helpers

    private func insertRule(
        collectionId: Int64,
        contentType: String? = nil,
        contentPattern: String? = nil,
        priority: Int = 0,
        enabled: Bool = true
    ) async throws {
        try await queue.write { db in
            var rule = CollectionRule(
                id: nil,
                collectionId: collectionId,
                contentType: contentType,
                contentPattern: contentPattern,
                priority: priority,
                enabled: enabled,
                createdAt: Date()
            )
            try rule.insert(db)
        }
    }

    private func makeEntry(
        content: String,
        contentType: ContentType = .text
    ) -> ClipboardEntry {
        ClipboardEntry(
            id: 1,
            content: content,
            contentType: contentType,
            createdAt: Date(),
            isFavorite: false
        )
    }

    // MARK: - Tests

    func testMatchesByContentType() async throws {
        let collection = try await collectionRepo.create(name: "URLs")
        let collectionId = try XCTUnwrap(collection.id)
        try await insertRule(collectionId: collectionId, contentType: "url")

        let entry = makeEntry(content: "https://example.com", contentType: .url)
        let result = try await engine.matchingCollections(for: entry, db: queue)

        XCTAssertEqual(result, [collectionId])
    }

    func testNoMatchWhenContentTypeDiffers() async throws {
        let collection = try await collectionRepo.create(name: "Emails")
        let collectionId = try XCTUnwrap(collection.id)
        try await insertRule(collectionId: collectionId, contentType: "email")

        let entry = makeEntry(content: "https://example.com", contentType: .url)
        let result = try await engine.matchingCollections(for: entry, db: queue)

        XCTAssertTrue(result.isEmpty)
    }

    func testMatchesByPattern() async throws {
        let collection = try await collectionRepo.create(name: "GitHub")
        let collectionId = try XCTUnwrap(collection.id)
        try await insertRule(collectionId: collectionId, contentPattern: "github\\.com")

        let entry = makeEntry(content: "https://github.com/niconi21/project", contentType: .url)
        let result = try await engine.matchingCollections(for: entry, db: queue)

        XCTAssertEqual(result, [collectionId])
    }

    func testNoMatchWhenPatternDoesNotMatch() async throws {
        let collection = try await collectionRepo.create(name: "GitHub")
        let collectionId = try XCTUnwrap(collection.id)
        try await insertRule(collectionId: collectionId, contentPattern: "github\\.com")

        let entry = makeEntry(content: "https://gitlab.com/foo/bar", contentType: .url)
        let result = try await engine.matchingCollections(for: entry, db: queue)

        XCTAssertTrue(result.isEmpty)
    }

    func testMatchesByBothContentTypeAndPattern() async throws {
        let collection = try await collectionRepo.create(name: "URL + GitHub")
        let collectionId = try XCTUnwrap(collection.id)
        try await insertRule(collectionId: collectionId, contentType: "url", contentPattern: "github\\.com")

        let matchingEntry = makeEntry(content: "https://github.com/niconi21", contentType: .url)
        let matchResult = try await engine.matchingCollections(for: matchingEntry, db: queue)
        XCTAssertEqual(matchResult, [collectionId])

        // Same pattern but wrong content type — should not match
        let wrongTypeEntry = makeEntry(content: "https://github.com/niconi21", contentType: .text)
        let wrongTypeResult = try await engine.matchingCollections(for: wrongTypeEntry, db: queue)
        XCTAssertTrue(wrongTypeResult.isEmpty)

        // Correct content type but pattern doesn't match
        let wrongPatternEntry = makeEntry(content: "https://gitlab.com/niconi21", contentType: .url)
        let wrongPatternResult = try await engine.matchingCollections(for: wrongPatternEntry, db: queue)
        XCTAssertTrue(wrongPatternResult.isEmpty)
    }

    func testDisabledRuleIsIgnored() async throws {
        let collection = try await collectionRepo.create(name: "Disabled")
        let collectionId = try XCTUnwrap(collection.id)
        try await insertRule(collectionId: collectionId, contentType: "url", enabled: false)

        let entry = makeEntry(content: "https://example.com", contentType: .url)
        let result = try await engine.matchingCollections(for: entry, db: queue)

        XCTAssertTrue(result.isEmpty)
    }

    func testReturnsUniqueCollectionIds() async throws {
        let collection = try await collectionRepo.create(name: "Multi-Rule")
        let collectionId = try XCTUnwrap(collection.id)

        // Two rules pointing to the same collection
        try await insertRule(collectionId: collectionId, contentType: "url", priority: 10)
        try await insertRule(collectionId: collectionId, contentPattern: "example\\.com", priority: 5)

        let entry = makeEntry(content: "https://example.com", contentType: .url)
        let result = try await engine.matchingCollections(for: entry, db: queue)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first, collectionId)
    }

    func testRulesEvaluatedInPriorityDescOrder() async throws {
        let collectionA = try await collectionRepo.create(name: "High Priority")
        let collectionB = try await collectionRepo.create(name: "Low Priority")
        let idA = try XCTUnwrap(collectionA.id)
        let idB = try XCTUnwrap(collectionB.id)

        try await insertRule(collectionId: idA, contentType: "url", priority: 100)
        try await insertRule(collectionId: idB, contentType: "url", priority: 1)

        let entry = makeEntry(content: "https://example.com", contentType: .url)
        let result = try await engine.matchingCollections(for: entry, db: queue)

        XCTAssertEqual(result.count, 2)
        // High priority collection must appear first
        XCTAssertEqual(result[0], idA)
        XCTAssertEqual(result[1], idB)
    }

    func testRuleWithNeitherFieldSetDoesNotMatch() async throws {
        let collection = try await collectionRepo.create(name: "Empty Rule")
        let collectionId = try XCTUnwrap(collection.id)
        // Insert a rule with neither contentType nor contentPattern
        try await insertRule(collectionId: collectionId, contentType: nil, contentPattern: nil)

        let entry = makeEntry(content: "anything", contentType: .text)
        let result = try await engine.matchingCollections(for: entry, db: queue)

        XCTAssertTrue(result.isEmpty)
    }

    func testEmptyRulesTableReturnsEmpty() async throws {
        let entry = makeEntry(content: "https://example.com", contentType: .url)
        let result = try await engine.matchingCollections(for: entry, db: queue)

        XCTAssertTrue(result.isEmpty)
    }
}
