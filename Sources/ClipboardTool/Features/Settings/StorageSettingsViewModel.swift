import Foundation
import GRDB
import os.log

@Observable
@MainActor
final class StorageSettingsViewModel {
    private static let logger = Logger(subsystem: "com.niconi21.clipboardtool", category: "storage")
    private let repository: ClipboardEntryRepository

    var dbPath: String {
        DatabaseManager.shared.pool.path
    }

    var showClearError = false
    var clearErrorMessage = ""

    init(repository: ClipboardEntryRepository = ClipboardEntryRepository()) {
        self.repository = repository
    }

    func clearHistory() async {
        do {
            try await repository.deleteAll()
        } catch {
            Self.logger.error("Failed to clear history: \(error.localizedDescription)")
            clearErrorMessage = error.localizedDescription
            showClearError = true
        }
    }
}
