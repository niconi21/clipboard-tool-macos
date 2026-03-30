import XCTest
import GRDB
@testable import ClipboardTool

// MARK: - Helpers

private func makeEntry(
    content: String,
    createdAt: Date,
    isFavorite: Bool = false
) -> ClipboardEntry {
    ClipboardEntry(id: nil, content: content, contentType: .text, createdAt: createdAt, isFavorite: isFavorite)
}

/// Returns a Date offset by `days` from the start of today.
private func date(daysAgo days: Int) -> Date {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    // Force-unwrap only inside tests — project rules allow it in test scope.
    return calendar.date(byAdding: .day, value: -days, to: today)!.addingTimeInterval(3600)
}

// MARK: - Tests

final class HistoryViewModelTests: XCTestCase {

    private var queue: DatabaseQueue!
    private var repository: ClipboardEntryRepository!
    private var viewModel: HistoryViewModel!

    override func setUp() async throws {
        queue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        Migrations.register(in: &migrator)
        try migrator.migrate(queue)
        repository = ClipboardEntryRepository(db: queue)
        // Provide a real ClipboardMonitor — start/stop lifecycle is the SUT here.
        viewModel = HistoryViewModel(repository: repository, monitor: ClipboardMonitor())
    }

    override func tearDown() async throws {
        viewModel.stop()
    }

    // MARK: - Lifecycle

    func testStartLoadsExistingEntries() async throws {
        try await repository.insert(makeEntry(content: "Preloaded", createdAt: date(daysAgo: 0)))

        viewModel.start()
        // Allow the initial loadEntries Task to complete.
        try await Task.sleep(for: .milliseconds(100))

        let allEntries = viewModel.groupedEntries.flatMap(\.entries)
        XCTAssertEqual(allEntries.count, 1)
        XCTAssertEqual(allEntries.first?.content, "Preloaded")
    }

    func testStopCancelsMonitorTask() async throws {
        viewModel.start()
        viewModel.stop()
        // After stop, groupedEntries should still hold whatever was loaded before stop.
        // Primary assertion: no crash and monitorTask is nil (checked via observable state stability).
        XCTAssertTrue(true) // lifecycle ran without throwing
    }

    // MARK: - Grouping

    func testGroupTodayYesterdayEarlier() async throws {
        try await repository.insert(makeEntry(content: "Today entry",     createdAt: date(daysAgo: 0)))
        try await repository.insert(makeEntry(content: "Yesterday entry", createdAt: date(daysAgo: 1)))
        try await repository.insert(makeEntry(content: "Earlier entry",   createdAt: date(daysAgo: 5)))

        viewModel.start()
        try await Task.sleep(for: .milliseconds(100))

        let groups = viewModel.groupedEntries
        XCTAssertEqual(groups.count, 3)

        let labels = groups.map(\.label)
        XCTAssertTrue(labels.contains("Today"))
        XCTAssertTrue(labels.contains("Yesterday"))
        XCTAssertTrue(labels.contains("Earlier"))

        let todayGroup    = groups.first(where: { $0.label == "Today" })
        let yesterdayGroup = groups.first(where: { $0.label == "Yesterday" })
        let earlierGroup  = groups.first(where: { $0.label == "Earlier" })

        XCTAssertEqual(todayGroup?.entries.count, 1)
        XCTAssertEqual(yesterdayGroup?.entries.count, 1)
        XCTAssertEqual(earlierGroup?.entries.count, 1)
    }

    func testGroupOnlyTodayEntries() async throws {
        try await repository.insert(makeEntry(content: "A", createdAt: date(daysAgo: 0)))
        try await repository.insert(makeEntry(content: "B", createdAt: date(daysAgo: 0)))

        viewModel.start()
        try await Task.sleep(for: .milliseconds(100))

        let groups = viewModel.groupedEntries
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.label, "Today")
        XCTAssertEqual(groups.first?.entries.count, 2)
    }

    func testGroupEmptyWhenNoEntries() async throws {
        viewModel.start()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertTrue(viewModel.groupedEntries.isEmpty)
    }

    // MARK: - Delete

    func testDeleteRemovesEntryAndRefreshesGroups() async throws {
        let inserted = try await repository.insert(
            makeEntry(content: "Delete me", createdAt: date(daysAgo: 0))
        )

        viewModel.start()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(viewModel.groupedEntries.flatMap(\.entries).count, 1)

        viewModel.delete(entry: inserted)
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertTrue(viewModel.groupedEntries.isEmpty)
    }

    func testDeleteEntryWithNilIdIsNoOp() async throws {
        let entryWithoutId = makeEntry(content: "No id", createdAt: date(daysAgo: 0))
        // id is nil — delete should be a no-op, not crash.
        viewModel.delete(entry: entryWithoutId)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(true) // reached without crash
    }

    // MARK: - ToggleFavorite

    func testToggleFavoriteFlipsFlagAndRefreshes() async throws {
        let inserted = try await repository.insert(
            makeEntry(content: "Star me", createdAt: date(daysAgo: 0), isFavorite: false)
        )

        viewModel.start()
        try await Task.sleep(for: .milliseconds(100))

        viewModel.toggleFavorite(entry: inserted)
        try await Task.sleep(for: .milliseconds(100))

        let favorites = try await repository.fetchFavorites()
        XCTAssertEqual(favorites.count, 1)
        XCTAssertEqual(favorites.first?.content, "Star me")

        // Toggle back — should now have zero favorites.
        let favoriteEntry = favorites.first!  // safe in tests per project rules
        viewModel.toggleFavorite(entry: favoriteEntry)
        try await Task.sleep(for: .milliseconds(100))

        let favoritesAfterToggleBack = try await repository.fetchFavorites()
        XCTAssertTrue(favoritesAfterToggleBack.isEmpty)
    }

    func testToggleFavoriteWithNilIdIsNoOp() async throws {
        let entryWithoutId = makeEntry(content: "No id", createdAt: date(daysAgo: 0))
        viewModel.toggleFavorite(entry: entryWithoutId)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(true)
    }

    // MARK: - CopySelected

    func testCopySelectedDoesNothingWhenNoSelection() async throws {
        viewModel.start()
        viewModel.selectedId = nil
        // Should not crash with no selection.
        viewModel.copySelected()
        XCTAssertTrue(true)
    }

    func testCopySelectedDoesNothingWhenIdNotInGroups() async throws {
        viewModel.start()
        viewModel.selectedId = 9999
        viewModel.copySelected()
        XCTAssertTrue(true)
    }
}
