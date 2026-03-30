import GRDB

enum Migrations {
    static func register(in migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1_initial_schema") { db in

            // clipboard_entries — main history table
            try db.create(table: "clipboard_entries") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("content", .text).notNull()
                t.column("content_type", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("is_favorite", .boolean).notNull().defaults(to: false)
            }

            // Indexes for all WHERE / ORDER BY columns (agent rule)
            try db.create(index: "idx_entries_created_at",
                          on: "clipboard_entries", columns: ["created_at"])
            try db.create(index: "idx_entries_content_type",
                          on: "clipboard_entries", columns: ["content_type"])
            try db.create(index: "idx_entries_is_favorite",
                          on: "clipboard_entries", columns: ["is_favorite"])

            // FTS5 virtual table for real-time full-text search (issue #12)
            // content= links it to clipboard_entries so we don't duplicate data
            try db.create(virtualTable: "clipboard_entries_fts", using: FTS5()) { t in
                t.synchronize(withTable: "clipboard_entries")
                t.tokenizer = .unicode61()
                t.column("content")
            }

            // collections — user-defined groups
            try db.create(table: "collections") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("created_at", .datetime).notNull()
            }

            // entry_collections — join table (many-to-many)
            try db.create(table: "entry_collections") { t in
                t.column("entry_id", .integer).notNull()
                    .references("clipboard_entries", onDelete: .cascade)
                t.column("collection_id", .integer).notNull()
                    .references("collections", onDelete: .cascade)
                t.primaryKey(["entry_id", "collection_id"])
            }
        }
    }
}
