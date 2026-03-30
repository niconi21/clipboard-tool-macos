import Foundation
import GRDB

struct Collection: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var name: String
    var createdAt: Date

    static let databaseTableName = "collections"

    enum Columns {
        static let id        = Column(CodingKeys.id)
        static let name      = Column(CodingKeys.name)
        static let createdAt = Column(CodingKeys.createdAt)
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
