import Foundation
import GRDB
import os.log

@Observable
@MainActor
final class ExportImportViewModel {
    private static let logger = Logger(subsystem: "com.niconi21.clipboardtool", category: "export")
    private let manager = ExportImportManager()
    private let db: any DatabaseWriter

    var showAlert = false
    var alertTitle = ""
    var alertMessage = ""

    init(db: any DatabaseWriter = DatabaseManager.shared.pool) {
        self.db = db
    }

    func export(to url: URL) async {
        do {
            let data = try await manager.export(db: db)
            try data.write(to: url)
            alertTitle = String(localized: "Export successful")
            alertMessage = String(localized: "Configuration exported successfully.")
        } catch {
            Self.logger.error("Export failed: \(error.localizedDescription)")
            alertTitle = String(localized: "Export failed")
            alertMessage = error.localizedDescription
        }
        showAlert = true
    }

    func `import`(from url: URL) async {
        do {
            let data = try Data(contentsOf: url)
            try await manager.import(data: data, db: db)
            alertTitle = String(localized: "Import successful")
            alertMessage = String(localized: "Configuration imported successfully.")
        } catch {
            Self.logger.error("Import failed: \(error.localizedDescription)")
            alertTitle = String(localized: "Import failed")
            alertMessage = error.localizedDescription
        }
        showAlert = true
    }
}
