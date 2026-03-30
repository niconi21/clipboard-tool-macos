import GRDB

// Join table: many-to-many between ClipboardEntry and Collection.
// No auto-increment id — composite primary key (entry_id, collection_id).
struct EntryCollection: Codable, FetchableRecord, PersistableRecord {
    var entryId: Int64
    var collectionId: Int64
    var subcollectionId: Int64?

    static let databaseTableName = "entry_collections"

    // Map Swift camelCase <-> SQL snake_case
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase

    enum Columns {
        static let entryId         = Column("entry_id")
        static let collectionId    = Column("collection_id")
        static let subcollectionId = Column("subcollection_id")
    }
}
