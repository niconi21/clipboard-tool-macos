import Foundation
import GRDB

final class DatabaseManager {
    static let shared = DatabaseManager()

    let pool: DatabasePool

    private init() {
        do {
            let url = try Self.databaseURL()
            var config = Configuration()
            config.label = "com.niconi21.clipboardtool"
            pool = try DatabasePool(path: url.path, configuration: config)
            try Self.runMigrations(pool)
        } catch {
            fatalError("Failed to open database: \(error)")
        }
    }

    private static func databaseURL() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("com.niconi21.clipboardtool", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("clipboard.db")
    }

    private static func runMigrations(_ pool: DatabasePool) throws {
        var migrator = DatabaseMigrator()
        Migrations.register(in: &migrator)
        try migrator.migrate(pool)
    }
}
