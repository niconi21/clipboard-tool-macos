import Foundation
import GRDB

// Represents a single item captured from the clipboard.
// Full schema and CRUD tracked in issue #8.
struct ClipboardEntry: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var content: String
    var contentType: ContentType
    var createdAt: Date
    var isFavorite: Bool

    static let databaseTableName = "clipboard_entries"
}
