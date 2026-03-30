import Foundation
import GRDB

struct AppSetting: Codable, FetchableRecord, PersistableRecord {
    var key: String
    var value: String
    var updatedAt: Date

    static let databaseTableName = "settings"
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase

    enum Columns {
        static let key       = Column("key")
        static let value     = Column("value")
        static let updatedAt = Column("updated_at")
    }
}
