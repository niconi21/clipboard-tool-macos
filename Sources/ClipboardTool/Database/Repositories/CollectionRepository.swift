import Foundation
import GRDB

struct CollectionRepository {
    private let db: any DatabaseWriter

    init(db: any DatabaseWriter = DatabaseManager.shared.pool) {
        self.db = db
    }

    // MARK: - Write

    @discardableResult
    func create(name: String) async throws -> Collection {
        try await db.write { db in
            var collection = Collection(id: nil, name: name, color: "#6b7280", isBuiltin: false, createdAt: Date())
            try collection.insert(db)
            return collection
        }
    }

    func rename(id: Int64, name: String) async throws {
        try await db.write { db in
            if var collection = try Collection.filter(key: id).fetchOne(db) {
                collection.name = name
                try collection.update(db)
            }
        }
    }

    /// Deletes the collection. The `entry_collections` rows are removed automatically via CASCADE.
    func delete(id: Int64) async throws {
        try await db.write { db in
            _ = try Collection.filter(key: id).deleteAll(db)
        }
    }

    // MARK: - Read

    func fetchAll() async throws -> [Collection] {
        try await db.read { db in
            try Collection
                .order(Collection.Columns.createdAt.asc)
                .fetchAll(db)
        }
    }

    func fetchEntries(collectionId: Int64) async throws -> [ClipboardEntry] {
        try await db.read { db in
            try ClipboardEntry.fetchAll(db, sql: """
                SELECT entries.*
                FROM entries
                JOIN entry_collections ON entries.id = entry_collections.entry_id
                WHERE entry_collections.collection_id = ?
                ORDER BY entries.created_at DESC
                LIMIT 500
            """, arguments: [collectionId])
        }
    }

    // MARK: - Entry membership

    func addEntry(_ entryId: Int64, to collectionId: Int64) async throws {
        try await db.write { db in
            let row = EntryCollection(entryId: entryId, collectionId: collectionId)
            try row.insert(db, onConflict: .ignore)
        }
    }

    func removeEntry(_ entryId: Int64, from collectionId: Int64) async throws {
        try await db.write { db in
            try EntryCollection
                .filter(EntryCollection.Columns.entryId == entryId)
                .filter(EntryCollection.Columns.collectionId == collectionId)
                .deleteAll(db)
        }
    }

    func fetchRules() async throws -> [CollectionRule] {
        try await db.read { db in
            try CollectionRule
                .filter(CollectionRule.Columns.enabled == true)
                .order(CollectionRule.Columns.priority.desc)
                .fetchAll(db)
        }
    }

    func fetchCollections(forEntryId entryId: Int64) async throws -> [Collection] {
        try await db.read { db in
            try Collection.fetchAll(db, sql: """
                SELECT collections.*
                FROM collections
                JOIN entry_collections ON collections.id = entry_collections.collection_id
                WHERE entry_collections.entry_id = ?
                ORDER BY collections.created_at ASC
                LIMIT 50
            """, arguments: [entryId])
        }
    }
}
