import Foundation
import GRDB

struct SettingsRepository {
    private let db: any DatabaseWriter

    init(db: any DatabaseWriter = DatabaseManager.shared.pool) {
        self.db = db
    }

    func get(key: String) async throws -> String? {
        try await db.read { db in
            try AppSetting.filter(key: key).fetchOne(db)?.value
        }
    }

    func set(key: String, value: String) async throws {
        try await db.write { db in
            let setting = AppSetting(key: key, value: value, updatedAt: Date())
            try setting.save(db)
        }
    }

    func fetchAll() async throws -> [AppSetting] {
        try await db.read { db in
            try AppSetting.fetchAll(db)
        }
    }
}
