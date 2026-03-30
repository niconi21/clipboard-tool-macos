import Foundation
import GRDB

struct ClipboardEntry: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var content: String
    var contentType: ContentType
    var createdAt: Date
    var isFavorite: Bool

    static let databaseTableName = "clipboard_entries"

    // Map Swift camelCase to SQL snake_case
    enum Columns {
        static let id          = Column(CodingKeys.id)
        static let content     = Column(CodingKeys.content)
        static let contentType = Column(CodingKeys.contentType)
        static let createdAt   = Column(CodingKeys.createdAt)
        static let isFavorite  = Column(CodingKeys.isFavorite)
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
