import Foundation
import GRDB

struct ClipboardEntryRepository {
    private let pool: DatabasePool

    init(pool: DatabasePool = DatabaseManager.shared.pool) {
        self.pool = pool
    }

    // MARK: - Write

    @discardableResult
    func insert(_ entry: ClipboardEntry) async throws -> ClipboardEntry {
        var entry = entry
        try await pool.write { db in
            try entry.insert(db)
        }
        return entry
    }

    func delete(id: Int64) async throws {
        try await pool.write { db in
            try ClipboardEntry.filter(key: id).deleteAll(db)
        }
    }

    func deleteAll() async throws {
        try await pool.write { db in
            try ClipboardEntry.deleteAll(db)
        }
    }

    func toggleFavorite(id: Int64) async throws {
        try await pool.write { db in
            if var entry = try ClipboardEntry.filter(key: id).fetchOne(db) {
                entry.isFavorite.toggle()
                try entry.update(db)
            }
        }
    }

    // MARK: - Read

    /// Paginated fetch ordered by most recent first.
    func fetchRecent(limit: Int = 50, offset: Int = 0) async throws -> [ClipboardEntry] {
        try await pool.read { db in
            try ClipboardEntry
                .order(ClipboardEntry.Columns.createdAt.desc)
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
    }

    /// Fetch only favorites.
    func fetchFavorites() async throws -> [ClipboardEntry] {
        try await pool.read { db in
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
        return try await pool.read { db in
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
        try await pool.read { db in
            try ClipboardEntry.fetchCount(db)
        }
    }

    /// Check if identical content already exists to avoid duplicates.
    func exists(content: String) async throws -> Bool {
        try await pool.read { db in
            try ClipboardEntry
                .filter(ClipboardEntry.Columns.content == content)
                .fetchOne(db) != nil
        }
    }
}
