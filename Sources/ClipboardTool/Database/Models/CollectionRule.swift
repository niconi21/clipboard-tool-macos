import Foundation
import GRDB

struct CollectionRule: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var collectionId: Int64
    var contentType: String?
    var contentPattern: String?
    var priority: Int
    var enabled: Bool
    var createdAt: Date

    static let databaseTableName = "collection_rules"
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase

    enum Columns {
        static let id             = Column("id")
        static let collectionId   = Column("collection_id")
        static let contentType    = Column("content_type")
        static let contentPattern = Column("content_pattern")
        static let priority       = Column("priority")
        static let enabled        = Column("enabled")
        static let createdAt      = Column("created_at")
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
