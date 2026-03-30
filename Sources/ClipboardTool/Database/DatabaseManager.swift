import Foundation
import GRDB

// Sets up and exposes the GRDB DatabasePool.
// Implementation tracked in issue #7.
final class DatabaseManager {
    static let shared = DatabaseManager()

    private(set) var pool: DatabasePool?

    private init() {
        // TODO: implement — issue #7
    }
}
