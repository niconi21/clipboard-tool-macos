import GRDB

// All database migrations in order.
// Never modify existing migrations — always add new ones.
// Implementation tracked in issue #7.
enum Migrations {
    static func register(in migrator: inout DatabaseMigrator) {
        // TODO: implement — issue #7
        // migrator.registerMigration("v1_initial") { db in ... }
    }
}
