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
                entry.isFavorite.toggle()
                try entry.update(db)
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
                SELECT clipboard_entries.*
                FROM clipboard_entries
                JOIN clipboard_entries_fts ON clipboard_entries.rowid = clipboard_entries_fts.rowid
                WHERE clipboard_entries_fts MATCH ?
                ORDER BY clipboard_entries.created_at DESC
            """, arguments: [pattern])
        }
    }

    /// Total count — useful for pagination UI.
    func count() async throws -> Int {
        try await db.read { db in
            try ClipboardEntry.fetchCount(db)
        }
    }

    /// Check if identical content already exists to avoid duplicates.
    func exists(content: String) async throws -> Bool {
        try await db.read { db in
            try ClipboardEntry
                .filter(ClipboardEntry.Columns.content == content)
                .fetchOne(db) != nil
        }
    }
}
