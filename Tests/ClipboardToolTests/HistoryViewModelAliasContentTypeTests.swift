import XCTest
import GRDB
@testable import ClipboardTool

// Tests for #23 (alias), #27 (content type override), #28 (reclassify)
final class HistoryViewModelAliasContentTypeTests: XCTestCase {

    private var queue: DatabaseQueue!
    private var repository: ClipboardEntryRepository!
    private var viewModel: HistoryViewModel!

    override func setUp() async throws {
        queue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        Migrations.register(in: &migrator)
        try migrator.migrate(queue)
        repository = ClipboardEntryRepository(db: queue)
        viewModel = HistoryViewModel(repository: repository, monitor: ClipboardMonitor())
    }

    override func tearDown() async throws {
        viewModel.stop()
    }

    // MARK: - setAlias (#23)

    func testSetAliasUpdatesEntry() async throws {
        let inserted = try await repository.insert(
            ClipboardEntry(id: nil, content: "alias test", contentType: .text,
                           createdAt: .now, isFavorite: false)
        )

        viewModel.start()
        try await Task.sleep(for: .milliseconds(100))

        viewModel.setAlias(id: inserted.id!, alias: "My Key")
        try await Task.sleep(for: .milliseconds(200))

        let fetched = try await repository.fetchRecent()
        XCTAssertEqual(fetched.first?.alias, "My Key")
    }

    func testSetAliasNilClearsAlias() async throws {
        let inserted = try await repository.insert(
            ClipboardEntry(id: nil, content: "clear alias", contentType: .text,
                           createdAt: .now, isFavorite: false, alias: "Old")
        )

        viewModel.start()
        try await Task.sleep(for: .milliseconds(100))

        viewModel.setAlias(id: inserted.id!, alias: nil)
        try await Task.sleep(for: .milliseconds(200))

        let fetched = try await repository.fetchRecent()
        XCTAssertNil(fetched.first?.alias)
    }

    // MARK: - setContentType (#27)

    func testSetContentTypeOverridesAndSetsManualFlag() async throws {
        let inserted = try await repository.insert(
            ClipboardEntry(id: nil, content: "https://example.com", contentType: .url,
                           createdAt: .now, isFavorite: false)
        )

        viewModel.start()
        try await Task.sleep(for: .milliseconds(100))

        viewModel.setContentType(id: inserted.id!, type: .text)
        try await Task.sleep(for: .milliseconds(200))

        let fetched = try await repository.fetchRecent()
        XCTAssertEqual(fetched.first?.contentType, .text)
        XCTAssertTrue(fetched.first?.manualOverride ?? false)
    }

    // MARK: - reclassifyAll (#28)

    func testReclassifyAllSkipsManualOverrideEntries() async throws {
        // This entry has manualOverride = true — reclassify must not touch it.
        var manualEntry = ClipboardEntry(id: nil, content: "https://example.com",
                                         contentType: .text, createdAt: .now, isFavorite: false)
        manualEntry.manualOverride = true
        let insertedManual = try await repository.insert(manualEntry)

        viewModel.start()
        try await Task.sleep(for: .milliseconds(100))

        viewModel.reclassifyAll()
        try await Task.sleep(for: .milliseconds(300))

        // manualOverride entry should still be .text (not reclassified to .url)
        let fetched = try await repository.fetchRecent()
        let found = fetched.first(where: { $0.id == insertedManual.id })
        XCTAssertEqual(found?.contentType, .text)
    }

    func testReclassifyAllUpdatesNonManualEntries() async throws {
        // Insert an entry with wrong type and manualOverride = false
        let inserted = try await repository.insert(
            ClipboardEntry(id: nil, content: "https://example.com",
                           contentType: .text,  // wrong — should be .url
                           createdAt: .now, isFavorite: false)
        )
        XCTAssertFalse(inserted.manualOverride)

        viewModel.start()
        try await Task.sleep(for: .milliseconds(100))

        viewModel.reclassifyAll()
        try await Task.sleep(for: .milliseconds(300))

        let fetched = try await repository.fetchRecent()
        let found = fetched.first(where: { $0.id == inserted.id })
        XCTAssertEqual(found?.contentType, .url)
        // manualOverride must stay false after automatic reclassification
        XCTAssertFalse(found?.manualOverride ?? true)
    }

    // MARK: - reclassifyEntry (#28)

    func testReclassifyEntrySkipsManualOverride() async throws {
        var manualEntry = ClipboardEntry(id: nil, content: "https://example.com",
                                          contentType: .text, createdAt: .now, isFavorite: false)
        manualEntry.manualOverride = true
        let inserted = try await repository.insert(manualEntry)

        viewModel.reclassifyEntry(entry: inserted)
        try await Task.sleep(for: .milliseconds(200))

        let fetched = try await repository.fetchRecent()
        XCTAssertEqual(fetched.first?.contentType, .text)
    }

    func testReclassifyEntryUpdatesType() async throws {
        let inserted = try await repository.insert(
            ClipboardEntry(id: nil, content: "https://example.com",
                           contentType: .text, createdAt: .now, isFavorite: false)
        )

        viewModel.reclassifyEntry(entry: inserted)
        try await Task.sleep(for: .milliseconds(200))

        let fetched = try await repository.fetchRecent()
        XCTAssertEqual(fetched.first?.contentType, .url)
        XCTAssertFalse(fetched.first?.manualOverride ?? true)
    }
}
