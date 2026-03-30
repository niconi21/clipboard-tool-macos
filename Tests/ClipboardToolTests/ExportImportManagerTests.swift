import XCTest
import GRDB
@testable import ClipboardTool

final class ExportImportManagerTests: XCTestCase {
    private var queue: DatabaseQueue!
    private let manager = ExportImportManager()

    override func setUp() async throws {
        queue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        Migrations.register(in: &migrator)
        try migrator.migrate(queue)
    }

    // MARK: - Helpers

    private func roundTrip() async throws -> ExportPayload {
        let data = try await manager.export(db: queue)
        let decoder = JSONDecoder()
        return try decoder.decode(ExportPayload.self, from: data)
    }

    // MARK: - Export tests

    func testExportProducesValidJSON() async throws {
        let data = try await manager.export(db: queue)
        XCTAssertFalse(data.isEmpty)
        // Must decode without throwing
        let payload = try JSONDecoder().decode(ExportPayload.self, from: data)
        XCTAssertEqual(payload.version, 1)
    }

    func testExportExcludesBuiltinCollections() async throws {
        // The seed inserts "Favorites" with is_builtin = true
        let payload = try await roundTrip()
        let names = payload.collections.map(\.name)
        XCTAssertFalse(names.contains("Favorites"))
    }

    func testExportIncludesUserCollections() async throws {
        try await queue.write { db in
            var c = Collection(name: "Work", color: "#ff0000", isBuiltin: false, createdAt: Date())
            try c.insert(db)
        }
        let payload = try await roundTrip()
        XCTAssertTrue(payload.collections.map(\.name).contains("Work"))
    }

    func testExportExcludesMachineSpecificSettings() async throws {
        try await queue.write { db in
            for key in ["window_x", "window_y", "window_width", "window_height"] {
                let s = AppSetting(key: key, value: "100", updatedAt: Date())
                try s.save(db)
            }
        }
        let payload = try await roundTrip()
        let keys = payload.settings.map(\.key)
        XCTAssertFalse(keys.contains("window_x"))
        XCTAssertFalse(keys.contains("window_y"))
        XCTAssertFalse(keys.contains("window_width"))
        XCTAssertFalse(keys.contains("window_height"))
    }

    func testExportIncludesExportableSettings() async throws {
        let payload = try await roundTrip()
        let keys = payload.settings.map(\.key)
        XCTAssertTrue(keys.contains("history_limit"))
    }

    func testExportExcludesBuiltinContentTypes() async throws {
        let payload = try await roundTrip()
        // All seeded content types are is_builtin = true, so the list must be empty
        XCTAssertTrue(payload.contentTypes.isEmpty)
    }

    func testExportedAtFormat() async throws {
        let payload = try await roundTrip()
        // Must match yyyy-MM-dd HH:mm:ss exactly (19 chars)
        XCTAssertEqual(payload.exportedAt.count, 19)
    }

    func testExportSubcollectionsLinkedToUserCollection() async throws {
        try await queue.write { db in
            var c = Collection(name: "Dev", color: "#000", isBuiltin: false, createdAt: Date())
            try c.insert(db)
            let cId = try XCTUnwrap(c.id)
            var sub = Subcollection(collectionId: cId, name: "Swift", isDefault: false, createdAt: Date())
            try sub.insert(db)
        }
        let payload = try await roundTrip()
        XCTAssertEqual(payload.subcollections.count, 1)
        XCTAssertEqual(payload.subcollections.first?.collectionName, "Dev")
        XCTAssertEqual(payload.subcollections.first?.name, "Swift")
    }

    func testExportCollectionRulesLinkedToUserCollection() async throws {
        try await queue.write { db in
            var c = Collection(name: "Links", color: "#aaa", isBuiltin: false, createdAt: Date())
            try c.insert(db)
            let cId = try XCTUnwrap(c.id)
            var rule = CollectionRule(
                collectionId: cId,
                contentType: "url",
                contentPattern: "^https://",
                priority: 10,
                enabled: true,
                createdAt: Date()
            )
            try rule.insert(db)
        }
        let payload = try await roundTrip()
        XCTAssertEqual(payload.collectionRules.count, 1)
        XCTAssertEqual(payload.collectionRules.first?.collectionName, "Links")
        XCTAssertEqual(payload.collectionRules.first?.contentType, "url")
    }

    // MARK: - Import tests

    func testImportInsertsNewCollection() async throws {
        let json = """
        {
          "version": 1,
          "exported_at": "2026-03-30 12:00:00",
          "settings": [],
          "collections": [{ "name": "Imported", "color": "#123456" }],
          "subcollections": [],
          "collection_rules": [],
          "content_types": []
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        try await manager.import(data: data, db: queue)

        let collections = try await queue.read { db in
            try Collection.fetchAll(db)
        }
        XCTAssertTrue(collections.map(\.name).contains("Imported"))
    }

    func testImportSkipsExistingCollectionByName() async throws {
        // Pre-insert the collection
        try await queue.write { db in
            var c = Collection(name: "Work", color: "#old", isBuiltin: false, createdAt: Date())
            try c.insert(db)
        }

        let json = """
        {
          "version": 1,
          "exported_at": "2026-03-30 12:00:00",
          "settings": [],
          "collections": [{ "name": "Work", "color": "#new" }],
          "subcollections": [],
          "collection_rules": [],
          "content_types": []
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        try await manager.import(data: data, db: queue)

        let collections = try await queue.read { db in
            try Collection.filter(Collection.Columns.name == "Work").fetchAll(db)
        }
        // Only one row should exist and the original color must be preserved
        XCTAssertEqual(collections.count, 1)
        XCTAssertEqual(collections.first?.color, "#old")
    }

    func testImportUpsertsSettings() async throws {
        let json = """
        {
          "version": 1,
          "exported_at": "2026-03-30 12:00:00",
          "settings": [{ "key": "history_limit", "value": "500" }],
          "collections": [],
          "subcollections": [],
          "collection_rules": [],
          "content_types": []
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        try await manager.import(data: data, db: queue)

        let setting = try await queue.read { db in
            try AppSetting.filter(Column("key") == "history_limit").fetchOne(db)
        }
        XCTAssertEqual(setting?.value, "500")
    }

    func testImportIgnoresMachineSpecificSettingsInFile() async throws {
        let json = """
        {
          "version": 1,
          "exported_at": "2026-03-30 12:00:00",
          "settings": [
            { "key": "window_x", "value": "200" },
            { "key": "window_y", "value": "300" }
          ],
          "collections": [],
          "subcollections": [],
          "collection_rules": [],
          "content_types": []
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        try await manager.import(data: data, db: queue)

        let windowX = try await queue.read { db in
            try AppSetting.filter(Column("key") == "window_x").fetchOne(db)
        }
        XCTAssertNil(windowX)
    }

    func testImportInsertsSubcollection() async throws {
        // Pre-insert the parent collection
        try await queue.write { db in
            var c = Collection(name: "Dev", color: "#000", isBuiltin: false, createdAt: Date())
            try c.insert(db)
        }

        let json = """
        {
          "version": 1,
          "exported_at": "2026-03-30 12:00:00",
          "settings": [],
          "collections": [{ "name": "Dev", "color": "#000" }],
          "subcollections": [{ "collection_name": "Dev", "name": "Swift", "is_default": false }],
          "collection_rules": [],
          "content_types": []
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        try await manager.import(data: data, db: queue)

        let subs = try await queue.read { db in try Subcollection.fetchAll(db) }
        XCTAssertTrue(subs.map(\.name).contains("Swift"))
    }

    func testImportSkipsDuplicateSubcollection() async throws {
        try await queue.write { db in
            var c = Collection(name: "Dev", color: "#000", isBuiltin: false, createdAt: Date())
            try c.insert(db)
            let cId = try XCTUnwrap(c.id)
            var sub = Subcollection(collectionId: cId, name: "Swift", isDefault: false, createdAt: Date())
            try sub.insert(db)
        }

        let json = """
        {
          "version": 1,
          "exported_at": "2026-03-30 12:00:00",
          "settings": [],
          "collections": [],
          "subcollections": [{ "collection_name": "Dev", "name": "Swift", "is_default": false }],
          "collection_rules": [],
          "content_types": []
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        try await manager.import(data: data, db: queue)

        let subs = try await queue.read { db in try Subcollection.fetchAll(db) }
        XCTAssertEqual(subs.filter { $0.name == "Swift" }.count, 1)
    }

    func testImportInsertsCollectionRule() async throws {
        try await queue.write { db in
            var c = Collection(name: "Links", color: "#aaa", isBuiltin: false, createdAt: Date())
            try c.insert(db)
        }

        let json = """
        {
          "version": 1,
          "exported_at": "2026-03-30 12:00:00",
          "settings": [],
          "collections": [{ "name": "Links", "color": "#aaa" }],
          "subcollections": [],
          "collection_rules": [
            {
              "collection_name": "Links",
              "content_type": "url",
              "content_pattern": "^https://",
              "priority": 10,
              "enabled": true
            }
          ],
          "content_types": []
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        try await manager.import(data: data, db: queue)

        let rules = try await queue.read { db in try CollectionRule.fetchAll(db) }
        XCTAssertTrue(rules.map(\.contentType).contains("url"))
    }

    func testImportInsertsUserContentType() async throws {
        let json = """
        {
          "version": 1,
          "exported_at": "2026-03-30 12:00:00",
          "settings": [],
          "collections": [],
          "subcollections": [],
          "collection_rules": [],
          "content_types": [{ "name": "xml", "label": "XML" }]
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        try await manager.import(data: data, db: queue)

        let exists = try await queue.read { db in
            try Row.fetchOne(db, sql: "SELECT 1 FROM content_types WHERE name = 'xml'")
        }
        XCTAssertNotNil(exists)
    }

    func testImportSkipsExistingContentType() async throws {
        // "text" is seeded as builtin — import must not add a second row
        let json = """
        {
          "version": 1,
          "exported_at": "2026-03-30 12:00:00",
          "settings": [],
          "collections": [],
          "subcollections": [],
          "collection_rules": [],
          "content_types": [{ "name": "text", "label": "Text" }]
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        try await manager.import(data: data, db: queue)

        let count = try await queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM content_types WHERE name = 'text'") ?? 0
        }
        XCTAssertEqual(count, 1)
    }

    func testImportThrowsOnInvalidJSON() async throws {
        let bad = Data("not json at all".utf8)
        do {
            try await manager.import(data: bad, db: queue)
            XCTFail("Expected error not thrown")
        } catch {
            // Expected
        }
    }

    // MARK: - Round-trip

    func testRoundTripPreservesCollections() async throws {
        try await queue.write { db in
            var c = Collection(name: "Round", color: "#abcdef", isBuiltin: false, createdAt: Date())
            try c.insert(db)
        }

        let data = try await manager.export(db: queue)

        // Import into a fresh DB
        let freshQueue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        Migrations.register(in: &migrator)
        try migrator.migrate(freshQueue)

        try await manager.import(data: data, db: freshQueue)

        let collections = try await freshQueue.read { db in
            try Collection.filter(Collection.Columns.isBuiltin == false).fetchAll(db)
        }
        XCTAssertEqual(collections.count, 1)
        XCTAssertEqual(collections.first?.name, "Round")
        XCTAssertEqual(collections.first?.color, "#abcdef")
    }
}
