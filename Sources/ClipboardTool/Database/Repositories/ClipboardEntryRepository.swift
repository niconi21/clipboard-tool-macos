import CryptoKit
import Foundation
import GRDB

struct ClipboardEntryRepository {
    private let db: any DatabaseWriter

    init(db: any DatabaseWriter = DatabaseManager.shared.pool) {
        self.db = db
    }

    // MARK: - Write

    @discardableResult
    func insert(_ entry: ClipboardEntry) async throws -> ClipboardEntry {
        try await db.write { db in
            var mutableEntry = entry
            let hashData = SHA256.hash(data: Data(entry.content.utf8))
            mutableEntry.contentHash = hashData.map { String(format: "%02x", $0) }.joined()
            try mutableEntry.insert(db)
            return mutableEntry
        }
    }

    func delete(id: Int64) async throws {
        try await db.write { db in
            _ = try ClipboardEntry.filter(key: id).deleteAll(db)
        }
    }

    func deleteAll() async throws {
        try await db.write { db in
            _ = try ClipboardEntry.deleteAll(db)
        }
    }

    func toggleFavorite(id: Int64) async throws {
        try await db.write { db in
            if var entry = try ClipboardEntry.filter(key: id).fetchOne(db) {
                try entry.updateChanges(db) {
                    $0.isFavorite.toggle()
                }
            }
        }
    }

    func updateAlias(id: Int64, alias: String?) async throws {
        try await db.write { db in
            if var entry = try ClipboardEntry.filter(key: id).fetchOne(db) {
                try entry.updateChanges(db) {
                    $0.alias = alias
                }
            }
        }
    }

    func updateContentType(id: Int64, contentType: ContentType) async throws {
        try await db.write { db in
            if var entry = try ClipboardEntry.filter(key: id).fetchOne(db) {
                try entry.updateChanges(db) {
                    $0.contentType = contentType
                    $0.manualOverride = true
                }
            }
        }
    }

    func clearManualOverride(id: Int64) async throws {
        try await db.write { db in
            if var entry = try ClipboardEntry.filter(key: id).fetchOne(db) {
                try entry.updateChanges(db) {
                    $0.manualOverride = false
                }
            }
        }
    }

    // MARK: - Read

    /// Paginated fetch ordered by most recent first.
    func fetchRecent(limit: Int = 50, offset: Int = 0) async throws -> [ClipboardEntry] {
        try await db.read { db in
            try ClipboardEntry
                .order(ClipboardEntry.Columns.createdAt.desc)
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
    }

    /// Fetch only favorites.
    func fetchFavorites() async throws -> [ClipboardEntry] {
        try await db.read { db in
            try ClipboardEntry
                .filter(ClipboardEntry.Columns.isFavorite == true)
                .order(ClipboardEntry.Columns.createdAt.desc)
                .limit(500)
                .fetchAll(db)
        }
    }

    /// Full-text search using FTS5. Returns entries matching all prefix words in query.
    func search(query: String) async throws -> [ClipboardEntry] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return try await fetchRecent()
        }
        return try await db.read { db in
            guard let pattern = FTS5Pattern(matchingAllPrefixesIn: query) else {
                return []
            }
            return try ClipboardEntry.fetchAll(db, sql: """
                SELECT entries.*
                FROM entries
                JOIN entries_fts ON entries.rowid = entries_fts.rowid
                WHERE entries_fts MATCH ?
                ORDER BY entries.created_at DESC
                LIMIT 100
            """, arguments: [pattern])
        }
    }

    /// Total count — useful for pagination UI.
    func count() async throws -> Int {
        try await db.read { db in
            try ClipboardEntry.fetchCount(db)
        }
    }

    /// Fetch every entry ordered by most recent first. Capped at 5000 for export only —
    /// loading the full table unbounded is unsafe for large histories.
    func fetchAll() async throws -> [ClipboardEntry] {
        try await db.read { db in
            try ClipboardEntry
                .order(ClipboardEntry.Columns.createdAt.desc)
                .limit(5000)
                .fetchAll(db)
        }
    }

    /// Check if an entry with the given SHA256 hash already exists — O(log n) via index.
    func exists(contentHash: String) async throws -> Bool {
        try await db.read { db in
            try ClipboardEntry
                .filter(ClipboardEntry.Columns.contentHash == contentHash)
                .fetchCount(db) > 0
        }
    }

    /// Check if identical content already exists to avoid duplicates.
    /// - Note: Deprecated — prefer `exists(contentHash:)` for O(log n) performance.
    @available(*, deprecated, renamed: "exists(contentHash:)")
    func exists(content: String) async throws -> Bool {
        try await db.read { db in
            try ClipboardEntry
                .filter(ClipboardEntry.Columns.content == content)
                .fetchOne(db) != nil
        }
    }
}
