import GRDB

enum Migrations {
    static func register(in migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1_initial_schema") { db in

            // entries — main history table (name matches Linux version for cross-platform compatibility)
            try db.create(table: "entries") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("content", .text).notNull()
                t.column("content_type", .text).notNull().defaults(to: "text")
                t.column("created_at", .datetime).notNull()
                t.column("is_favorite", .boolean).notNull().defaults(to: false)
                t.column("source_app", .text)
                t.column("window_title", .text)
                t.column("alias", .text)
                t.column("manual_override", .boolean).notNull().defaults(to: false)
            }

            try db.create(index: "idx_entries_created_at",   on: "entries", columns: ["created_at"])
            try db.create(index: "idx_entries_content_type", on: "entries", columns: ["content_type"])
            try db.create(index: "idx_entries_is_favorite",  on: "entries", columns: ["is_favorite"])

            // FTS5 virtual table for full-text search
            try db.create(virtualTable: "entries_fts", using: FTS5()) { t in
                t.synchronize(withTable: "entries")
                t.tokenizer = .unicode61()
                t.column("content")
                t.column("alias")
            }

            // collections — user-defined groups (schema matches Linux)
            try db.create(table: "collections") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("color", .text).notNull().defaults(to: "#6b7280")
                t.column("is_builtin", .boolean).notNull().defaults(to: false)
                t.column("created_at", .datetime).notNull()
            }

            // subcollections — one level of hierarchy within collections
            try db.create(table: "subcollections") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("collection_id", .integer).notNull()
                    .references("collections", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("is_default", .boolean).notNull().defaults(to: false)
                t.column("created_at", .datetime).notNull()
                t.uniqueKey(["collection_id", "name"])
            }
            try db.create(index: "idx_subcollections_collection",
                          on: "subcollections", columns: ["collection_id"])

            // entry_collections — many-to-many join table
            try db.create(table: "entry_collections") { t in
                t.column("entry_id", .integer).notNull()
                    .references("entries", onDelete: .cascade)
                t.column("collection_id", .integer).notNull()
                    .references("collections", onDelete: .cascade)
                t.column("subcollection_id", .integer)
                t.primaryKey(["entry_id", "collection_id"])
            }
            try db.create(index: "idx_ec_subcollection_id",
                          on: "entry_collections", columns: ["subcollection_id"])

            // collection_rules — auto-assign entries to collections via rules
            try db.create(table: "collection_rules") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("collection_id", .integer).notNull()
                    .references("collections", onDelete: .cascade)
                t.column("content_type", .text)
                t.column("content_pattern", .text)
                t.column("priority", .integer).notNull().defaults(to: 0)
                t.column("enabled", .boolean).notNull().defaults(to: true)
                t.column("created_at", .datetime).notNull()
            }
            try db.create(index: "idx_collection_rules_collection",
                          on: "collection_rules", columns: ["collection_id"])

            // settings — exportable key-value store (matches Linux schema)
            try db.create(table: "settings") { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text).notNull()
                t.column("updated_at", .datetime).notNull()
            }

            // content_types — reference table matching Linux type names exactly
            try db.create(table: "content_types") { t in
                t.column("name", .text).primaryKey()
                t.column("label", .text).notNull()
                t.column("is_builtin", .boolean).notNull().defaults(to: true)
                t.column("created_at", .datetime).notNull()
            }

            // --- Seed data ---

            let seedDate = "2026-01-01T00:00:00.000"

            // Builtin Favorites collection
            try db.execute(
                sql: "INSERT INTO collections (name, color, is_builtin, created_at) VALUES ('Favorites', '#f59e0b', 1, ?)",
                arguments: [seedDate]
            )

            // Settings defaults
            try db.execute(
                sql: """
                    INSERT INTO settings (key, value, updated_at) VALUES
                        ('history_limit', '100', ?),
                        ('pause_duration', '5', ?)
                """,
                arguments: [seedDate, seedDate]
            )

            // Content types — all 10, names match Linux exactly
            let contentTypes: [(String, String)] = [
                ("text",     "Text"),
                ("url",      "URL"),
                ("email",    "Email"),
                ("phone",    "Phone"),
                ("color",    "Color"),
                ("code",     "Code"),
                ("json",     "JSON"),
                ("sql",      "SQL"),
                ("shell",    "Shell"),
                ("markdown", "Markdown"),
            ]
            for (name, label) in contentTypes {
                try db.execute(
                    sql: "INSERT INTO content_types (name, label, created_at) VALUES (?, ?, ?)",
                    arguments: [name, label, seedDate]
                )
            }
        }
    }
}
