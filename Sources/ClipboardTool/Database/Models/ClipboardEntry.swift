import Foundation
import GRDB

struct ClipboardEntry: Codable, FetchableRecord, MutablePersistableRecord, Identifiable {
    var id: Int64?
    var content: String
    var contentType: ContentType
    var createdAt: Date
    var isFavorite: Bool
    var sourceApp: String?
    var windowTitle: String?
    var alias: String?
    var manualOverride: Bool

    init(
        id: Int64? = nil,
        content: String,
        contentType: ContentType,
        createdAt: Date,
        isFavorite: Bool,
        sourceApp: String? = nil,
        windowTitle: String? = nil,
        alias: String? = nil,
        manualOverride: Bool = false
    ) {
        self.id = id
        self.content = content
        self.contentType = contentType
        self.createdAt = createdAt
        self.isFavorite = isFavorite
        self.sourceApp = sourceApp
        self.windowTitle = windowTitle
        self.alias = alias
        self.manualOverride = manualOverride
    }

    static let databaseTableName = "entries"

    // Map Swift camelCase ↔ SQL snake_case
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase

    enum Columns {
        static let id             = Column("id")
        static let content        = Column("content")
        static let contentType    = Column("content_type")
        static let createdAt      = Column("created_at")
        static let isFavorite     = Column("is_favorite")
        static let sourceApp      = Column("source_app")
        static let windowTitle    = Column("window_title")
        static let alias          = Column("alias")
        static let manualOverride = Column("manual_override")
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
