import XCTest
import GRDB
@testable import ClipboardTool

// MARK: - Helpers

private func makeEntry(
    content: String,
    createdAt: Date = Date(),
    isFavorite: Bool = false
) -> ClipboardEntry {
    ClipboardEntry(id: nil, content: content, contentType: .text, createdAt: createdAt, isFavorite: isFavorite)
}

// MARK: - Tests

final class HistoryViewModelSearchTests: XCTestCase {

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

    // MARK: - testSearchTextDebounceFiltersEntries

    func testSearchTextDebounceFiltersEntries() async throws {
        try await repository.insert(makeEntry(content: "Hello swift world"))
        try await repository.insert(makeEntry(content: "Unrelated item"))

        viewModel.start()
        // Wait for initial load.
        try await Task.sleep(for: .milliseconds(100))

        // Trigger search — debounce is 150 ms.
        viewModel.searchText = "swift"
        // Wait long enough for debounce + async load.
        try await Task.sleep(for: .milliseconds(300))

        let groups = viewModel.groupedEntries
        XCTAssertEqual(groups.count, 1)

        let allEntries = groups.flatMap(\.entries)
        XCTAssertEqual(allEntries.count, 1)
        XCTAssertEqual(allEntries.first?.content, "Hello swift world")

        // Section label should reflect result count.
        XCTAssertEqual(groups.first?.label, "1 result")
    }

    // MARK: - testEmptySearchShowsAllEntries

    func testEmptySearchShowsAllEntries() async throws {
        try await repository.insert(makeEntry(content: "First entry"))
        try await repository.insert(makeEntry(content: "Second entry"))

        viewModel.start()
        try await Task.sleep(for: .milliseconds(100))

        // Apply a search first, then clear it.
        viewModel.searchText = "First"
        try await Task.sleep(for: .milliseconds(300))

        viewModel.searchText = ""
        try await Task.sleep(for: .milliseconds(300))

        let allEntries = viewModel.groupedEntries.flatMap(\.entries)
        XCTAssertEqual(allEntries.count, 2)

        // With empty search, grouping by date is used — no "N results" label.
        let hasResultsLabel = viewModel.groupedEntries.contains { $0.label.contains("result") }
        XCTAssertFalse(hasResultsLabel)
    }

    // MARK: - testSearchWithNoResultsReturnsEmptyGroups

    func testSearchWithNoResultsReturnsEmptyGroups() async throws {
        try await repository.insert(makeEntry(content: "Hello world"))

        viewModel.start()
        try await Task.sleep(for: .milliseconds(100))

        viewModel.searchText = "zzznomatch"
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertTrue(viewModel.groupedEntries.isEmpty)
    }

    // MARK: - testSearchResultLabelPluralization

    func testSearchResultLabelPluralization() async throws {
        try await repository.insert(makeEntry(content: "Swift tips"))
        try await repository.insert(makeEntry(content: "Swift tricks"))

        viewModel.start()
        try await Task.sleep(for: .milliseconds(100))

        viewModel.searchText = "Swift"
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(viewModel.groupedEntries.count, 1)
        XCTAssertEqual(viewModel.groupedEntries.first?.label, "2 results")
    }

    // MARK: - testDebounceCoalescesFastTyping

    func testDebounceCoalescesFastTyping() async throws {
        try await repository.insert(makeEntry(content: "Hello swift world"))
        try await repository.insert(makeEntry(content: "Unrelated item"))

        viewModel.start()
        try await Task.sleep(for: .milliseconds(100))

        // Simulate fast typing: set text several times within the debounce window.
        viewModel.searchText = "s"
        viewModel.searchText = "sw"
        viewModel.searchText = "swi"
        viewModel.searchText = "swift"

        // Only one load should happen — after the final 150 ms debounce fires.
        try await Task.sleep(for: .milliseconds(300))

        let allEntries = viewModel.groupedEntries.flatMap(\.entries)
        XCTAssertEqual(allEntries.count, 1)
        XCTAssertEqual(allEntries.first?.content, "Hello swift world")
    }
}
