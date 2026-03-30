import XCTest
import GRDB
@testable import ClipboardTool

final class HomologationMigrationTests: XCTestCase {
    private var queue: DatabaseQueue!

    override func setUp() async throws {
        queue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        Migrations.register(in: &migrator)
        try migrator.migrate(queue)
    }

    // MARK: - entries table columns

    func testClipboardEntryHasNewColumns() async throws {
        let entry = ClipboardEntry(
            id: nil,
            content: "alias test",
            contentType: .text,
            createdAt: .now,
            isFavorite: false,
            sourceApp: "Safari",
            windowTitle: "My Window",
            alias: "work-snippet",
            manualOverride: true
        )
        let inserted = try await queue.write { db -> ClipboardEntry in
            var e = entry
            try e.insert(db)
            return e
        }
        XCTAssertNotNil(inserted.id)

        let fetched = try await queue.read { db in
            try ClipboardEntry.filter(key: inserted.id!).fetchOne(db)
        }
        XCTAssertEqual(fetched?.alias, "work-snippet")
        XCTAssertEqual(fetched?.sourceApp, "Safari")
        XCTAssertEqual(fetched?.windowTitle, "My Window")
        XCTAssertEqual(fetched?.manualOverride, true)
    }

    // MARK: - collections new columns

    func testCollectionHasColorAndIsBuiltin() async throws {
        let inserted = try await queue.write { db -> Collection in
            var c = Collection(id: nil, name: "Design", color: "#ff5733", isBuiltin: true, createdAt: .now)
            try c.insert(db)
            return c
        }
        XCTAssertNotNil(inserted.id)

        let fetched = try await queue.read { db in
            try Collection.filter(key: inserted.id!).fetchOne(db)
        }
        XCTAssertEqual(fetched?.color, "#ff5733")
        XCTAssertEqual(fetched?.isBuiltin, true)
    }

    // MARK: - entry_collections subcollection_id column

    func testEntryCollectionHasSubcollectionId() async throws {
        // Setup: need a real entry and collection to satisfy FK constraints
        let (entryId, collectionId) = try await queue.write { db -> (Int64, Int64) in
            var entry = ClipboardEntry(id: nil, content: "ec test", contentType: .text,
                                       createdAt: .now, isFavorite: false)
            try entry.insert(db)
            var col = Collection(id: nil, name: "EC Col", createdAt: .now)
            try col.insert(db)
            return (entry.id!, col.id!)
        }

        let ec = EntryCollection(entryId: entryId, collectionId: collectionId, subcollectionId: nil)
        try await queue.write { db in
            try ec.insert(db, onConflict: .ignore)
        }

        let fetched = try await queue.read { db in
            try EntryCollection
                .filter(EntryCollection.Columns.entryId == entryId)
                .filter(EntryCollection.Columns.collectionId == collectionId)
                .fetchOne(db)
        }
        XCTAssertNotNil(fetched)
        XCTAssertNil(fetched?.subcollectionId)
    }

    // MARK: - Subcollection model round-trip

    func testSubcollectionModelRoundTrip() async throws {
        let collectionId = try await queue.write { db -> Int64 in
            var col = Collection(id: nil, name: "Sub Parent", createdAt: .now)
            try col.insert(db)
            return col.id!
        }

        let now = Date()
        let inserted = try await queue.write { db -> Subcollection in
            var sub = Subcollection(id: nil, collectionId: collectionId,
                                    name: "Swift snippets", isDefault: true, createdAt: now)
            try sub.insert(db)
            return sub
        }
        XCTAssertNotNil(inserted.id)

        let fetched = try await queue.read { db in
            try Subcollection.filter(key: inserted.id!).fetchOne(db)
        }
        XCTAssertEqual(fetched?.name, "Swift snippets")
        XCTAssertEqual(fetched?.isDefault, true)
        XCTAssertEqual(fetched?.collectionId, collectionId)
    }

    // MARK: - CollectionRule model round-trip

    func testCollectionRuleModelRoundTrip() async throws {
        let collectionId = try await queue.write { db -> Int64 in
            var col = Collection(id: nil, name: "Rules Parent", createdAt: .now)
            try col.insert(db)
            return col.id!
        }

        let now = Date()
        let inserted = try await queue.write { db -> CollectionRule in
            var rule = CollectionRule(
                id: nil,
                collectionId: collectionId,
                contentType: "url",
                contentPattern: #"^https://"#,
                priority: 10,
                enabled: true,
                createdAt: now
            )
            try rule.insert(db)
            return rule
        }
        XCTAssertNotNil(inserted.id)

        let fetched = try await queue.read { db in
            try CollectionRule.filter(key: inserted.id!).fetchOne(db)
        }
        XCTAssertEqual(fetched?.contentType, "url")
        XCTAssertEqual(fetched?.contentPattern, #"^https://"#)
        XCTAssertEqual(fetched?.priority, 10)
        XCTAssertEqual(fetched?.enabled, true)
    }

    // MARK: - Settings seed data

    func testSettingsSeedData() async throws {
        let settings = try await queue.read { db in
            try AppSetting.fetchAll(db)
        }
        let keys = Set(settings.map(\.key))
        XCTAssertTrue(keys.contains("history_limit"), "history_limit must be seeded")
        XCTAssertTrue(keys.contains("pause_duration"), "pause_duration must be seeded")

        let historyLimit = settings.first(where: { $0.key == "history_limit" })
        let pauseDuration = settings.first(where: { $0.key == "pause_duration" })
        XCTAssertEqual(historyLimit?.value, "100")
        XCTAssertEqual(pauseDuration?.value, "5")
    }

    // MARK: - Content types seed data

    func testContentTypesSeedData() async throws {
        let expectedNames: Set<String> = [
            "text", "url", "email", "phone", "color",
            "code", "json", "sql", "shell", "markdown",
        ]

        let names = try await queue.read { db -> Set<String> in
            let rows = try Row.fetchAll(db, sql: "SELECT name FROM content_types")
            return Set(rows.map { $0["name"] as String })
        }

        XCTAssertEqual(names, expectedNames,
                       "All 10 content types must be seeded with exact Linux-compatible names")
    }
}
