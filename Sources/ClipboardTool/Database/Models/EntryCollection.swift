import GRDB

// Join table: many-to-many between ClipboardEntry and Collection
struct EntryCollection: Codable, FetchableRecord, PersistableRecord {
    var entryId: Int64
    var collectionId: Int64

    static let databaseTableName = "entry_collections"

    enum Columns {
        static let entryId      = Column(CodingKeys.entryId)
        static let collectionId = Column(CodingKeys.collectionId)
    }
}
