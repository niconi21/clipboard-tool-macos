import Foundation
import GRDB

// MARK: - JSON shapes (Linux-compatible format)

struct ExportPayload: Codable {
    var version: Int
    var exportedAt: String
    var settings: [ExportedSetting]
    var collections: [ExportedCollection]
    var subcollections: [ExportedSubcollection]
    var collectionRules: [ExportedCollectionRule]
    var contentTypes: [ExportedContentType]

    enum CodingKeys: String, CodingKey {
        case version
        case exportedAt      = "exported_at"
        case settings
        case collections
        case subcollections
        case collectionRules = "collection_rules"
        case contentTypes    = "content_types"
    }
}

struct ExportedSetting: Codable {
    var key: String
    var value: String
}

struct ExportedCollection: Codable {
    var name: String
    var color: String
}

struct ExportedSubcollection: Codable {
    var collectionName: String
    var name: String
    var isDefault: Bool

    enum CodingKeys: String, CodingKey {
        case collectionName = "collection_name"
        case name
        case isDefault      = "is_default"
    }
}

struct ExportedCollectionRule: Codable {
    var collectionName: String
    var contentType: String?
    var contentPattern: String?
    var priority: Int
    var enabled: Bool

    enum CodingKeys: String, CodingKey {
        case collectionName  = "collection_name"
        case contentType     = "content_type"
        case contentPattern  = "content_pattern"
        case priority
        case enabled
    }
}

struct ExportedContentType: Codable {
    var name: String
    var label: String
}

// MARK: - Manager

/// Handles export and import of user configuration in a Linux-compatible JSON format.
/// All database access must go through the `db` parameter — never through `DatabaseManager.shared.pool` directly.
struct ExportImportManager {

    // Settings keys that are machine-specific and must not be exported
    private static let excludedSettingKeys: Set<String> = [
        "window_x", "window_y", "window_width", "window_height"
    ]

    private static let exportedAtFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    // MARK: - Export

    /// Reads all user-created (non-builtin) records and serialises them as JSON `Data`.
    func export(db: any DatabaseReader) async throws -> Data {
        let payload = try await db.read { db -> ExportPayload in
            // Settings (all keys are exportable except machine-specific ones)
            let rawSettings = try AppSetting.fetchAll(db)
            let settings = rawSettings
                .filter { !ExportImportManager.excludedSettingKeys.contains($0.key) }
                .map { ExportedSetting(key: $0.key, value: $0.value) }

            // User-created collections only
            let userCollections = try Collection
                .filter(Collection.Columns.isBuiltin == false)
                .fetchAll(db)

            let collections = userCollections.map {
                ExportedCollection(name: $0.name, color: $0.color)
            }

            // Subcollections that belong to user-created collections
            let userCollectionIds = userCollections.compactMap(\.id)
            var subcollections: [ExportedSubcollection] = []
            if !userCollectionIds.isEmpty {
                let rawSubs = try Subcollection
                    .filter(userCollectionIds.contains(Subcollection.Columns.collectionId))
                    .fetchAll(db)

                let collectionById = Dictionary(
                    uniqueKeysWithValues: userCollections.compactMap { c -> (Int64, String)? in
                        guard let id = c.id else { return nil }
                        return (id, c.name)
                    }
                )

                subcollections = rawSubs.compactMap { sub in
                    guard let parentName = collectionById[sub.collectionId] else { return nil }
                    return ExportedSubcollection(
                        collectionName: parentName,
                        name: sub.name,
                        isDefault: sub.isDefault
                    )
                }
            }

            // Collection rules for user-created collections
            var collectionRules: [ExportedCollectionRule] = []
            if !userCollectionIds.isEmpty {
                let rawRules = try CollectionRule
                    .filter(userCollectionIds.contains(CollectionRule.Columns.collectionId))
                    .fetchAll(db)

                let collectionById = Dictionary(
                    uniqueKeysWithValues: userCollections.compactMap { c -> (Int64, String)? in
                        guard let id = c.id else { return nil }
                        return (id, c.name)
                    }
                )

                collectionRules = rawRules.compactMap { rule in
                    guard let parentName = collectionById[rule.collectionId] else { return nil }
                    return ExportedCollectionRule(
                        collectionName: parentName,
                        contentType: rule.contentType,
                        contentPattern: rule.contentPattern,
                        priority: rule.priority,
                        enabled: rule.enabled
                    )
                }
            }

            // User-created content types only (is_builtin = false)
            let rawContentTypes = try Row.fetchAll(db, sql: """
                SELECT name, label FROM content_types WHERE is_builtin = 0 ORDER BY name
            """)
            let contentTypes = rawContentTypes.map {
                ExportedContentType(name: $0["name"], label: $0["label"])
            }

            return ExportPayload(
                version: 1,
                exportedAt: ExportImportManager.exportedAtFormatter.string(from: Date()),
                settings: settings,
                collections: collections,
                subcollections: subcollections,
                collectionRules: collectionRules,
                contentTypes: contentTypes
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    // MARK: - Import

    /// Parses a JSON payload and inserts missing records.
    /// - Settings are upserted (insert or replace).
    /// - Collections/subcollections/rules are skipped if a record with the same name/key already exists.
    /// - Machine-specific settings keys are ignored even if present in the file.
    func `import`(data: Data, db: any DatabaseWriter) async throws {
        let decoder = JSONDecoder()
        let payload = try decoder.decode(ExportPayload.self, from: data)

        try await db.write { db in
            let now = Date()

            // --- Settings (upsert) ---
            for setting in payload.settings {
                guard !ExportImportManager.excludedSettingKeys.contains(setting.key) else { continue }
                let record = AppSetting(key: setting.key, value: setting.value, updatedAt: now)
                try record.save(db)
            }

            // --- Collections (skip-if-exists by name) ---
            let existingCollectionNames = Set(
                try Collection.fetchAll(db).map(\.name)
            )

            var importedCollectionsByName: [String: Collection] = [:]

            for exportedCollection in payload.collections {
                if existingCollectionNames.contains(exportedCollection.name) {
                    // Fetch the existing one so we can reference it for subcollections/rules
                    if let existing = try Collection
                        .filter(Collection.Columns.name == exportedCollection.name)
                        .fetchOne(db) {
                        importedCollectionsByName[exportedCollection.name] = existing
                    }
                    continue
                }
                var record = Collection(
                    name: exportedCollection.name,
                    color: exportedCollection.color,
                    isBuiltin: false,
                    createdAt: now
                )
                try record.insert(db)
                importedCollectionsByName[exportedCollection.name] = record
            }

            // Build a full name→id map that includes pre-existing collections
            let allCollections = try Collection.fetchAll(db)
            let collectionIdByName = Dictionary(
                uniqueKeysWithValues: allCollections.compactMap { c -> (String, Int64)? in
                    guard let id = c.id else { return nil }
                    return (c.name, id)
                }
            )

            // --- Subcollections (skip-if-exists by collection_id + name) ---
            let existingSubcollections = try Subcollection.fetchAll(db)
            let existingSubKey = Set(existingSubcollections.map { "\($0.collectionId)|\($0.name)" })

            for exportedSub in payload.subcollections {
                guard let collectionId = collectionIdByName[exportedSub.collectionName] else { continue }
                let key = "\(collectionId)|\(exportedSub.name)"
                guard !existingSubKey.contains(key) else { continue }

                var record = Subcollection(
                    collectionId: collectionId,
                    name: exportedSub.name,
                    isDefault: exportedSub.isDefault,
                    createdAt: now
                )
                try record.insert(db)
            }

            // --- Collection rules (skip-if-exists by collection_id + content_type + content_pattern) ---
            let existingRules = try CollectionRule.fetchAll(db)
            let existingRuleKey = Set(existingRules.map {
                "\($0.collectionId)|\($0.contentType ?? "")|\($0.contentPattern ?? "")"
            })

            for exportedRule in payload.collectionRules {
                guard let collectionId = collectionIdByName[exportedRule.collectionName] else { continue }
                let key = "\(collectionId)|\(exportedRule.contentType ?? "")|\(exportedRule.contentPattern ?? "")"
                guard !existingRuleKey.contains(key) else { continue }

                var record = CollectionRule(
                    collectionId: collectionId,
                    contentType: exportedRule.contentType,
                    contentPattern: exportedRule.contentPattern,
                    priority: exportedRule.priority,
                    enabled: exportedRule.enabled,
                    createdAt: now
                )
                try record.insert(db)
            }

            // --- Content types (skip-if-exists by name) ---
            let existingTypeNames = Set(
                try Row.fetchAll(db, sql: "SELECT name FROM content_types").map { $0["name"] as String }
            )

            for ct in payload.contentTypes {
                guard !existingTypeNames.contains(ct.name) else { continue }
                try db.execute(
                    sql: "INSERT INTO content_types (name, label, is_builtin, created_at) VALUES (?, ?, 0, ?)",
                    arguments: [ct.name, ct.label, now]
                )
            }
        }
    }
}
