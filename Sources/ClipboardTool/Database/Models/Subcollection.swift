import Foundation
import GRDB

struct Subcollection: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var collectionId: Int64
    var name: String
    var isDefault: Bool
    var createdAt: Date

    static let databaseTableName = "subcollections"
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase

    enum Columns {
        static let id           = Column("id")
        static let collectionId = Column("collection_id")
        static let name         = Column("name")
        static let isDefault    = Column("is_default")
        static let createdAt    = Column("created_at")
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
