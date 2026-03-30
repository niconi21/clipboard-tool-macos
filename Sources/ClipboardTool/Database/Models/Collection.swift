import Foundation
import GRDB

struct Collection: Codable, FetchableRecord, MutablePersistableRecord, Hashable {
    var id: Int64?
    var name: String
    var color: String
    var isBuiltin: Bool
    var createdAt: Date

    init(
        id: Int64? = nil,
        name: String,
        color: String = "#6b7280",
        isBuiltin: Bool = false,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.isBuiltin = isBuiltin
        self.createdAt = createdAt
    }

    static let databaseTableName = "collections"

    // Map Swift camelCase <-> SQL snake_case
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase

    enum Columns {
        static let id        = Column("id")
        static let name      = Column("name")
        static let color     = Column("color")
        static let isBuiltin = Column("is_builtin")
        static let createdAt = Column("created_at")
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
