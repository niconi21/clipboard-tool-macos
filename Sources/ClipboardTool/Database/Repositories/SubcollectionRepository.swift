import Foundation
import GRDB

struct SubcollectionRepository {
    private let db: any DatabaseWriter

    init(db: any DatabaseWriter = DatabaseManager.shared.pool) {
        self.db = db
    }

    // MARK: - Read

    func fetchAll(for collectionId: Int64) async throws -> [Subcollection] {
        try await db.read { database in
            try Subcollection
                .filter(Subcollection.Columns.collectionId == collectionId)
                .order(Subcollection.Columns.createdAt.asc)
                .fetchAll(database)
        }
    }

    // MARK: - Write

    @discardableResult
    func create(name: String, collectionId: Int64) async throws -> Subcollection {
        try await db.write { database in
            var subcollection = Subcollection(
                id: nil,
                collectionId: collectionId,
                name: name,
                isDefault: false,
                createdAt: Date()
            )
            try subcollection.insert(database)
            return subcollection
        }
    }

    func delete(id: Int64) async throws {
        try await db.write { database in
            _ = try Subcollection.filter(key: id).deleteAll(database)
        }
    }

    func rename(id: Int64, name: String) async throws {
        try await db.write { database in
            if var subcollection = try Subcollection.filter(key: id).fetchOne(database) {
                subcollection.name = name
                try subcollection.update(database)
            }
        }
    }
}
