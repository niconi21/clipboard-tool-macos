import Foundation
import GRDB

// User-defined group of clipboard entries.
// Implementation tracked in issue #9.
struct Collection: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var name: String
    var createdAt: Date

    static let databaseTableName = "collections"
}
