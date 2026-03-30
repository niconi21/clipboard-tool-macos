import Foundation
import AppKit

@Observable
final class HistoryViewModel {

    // MARK: - State (read by View)

    private(set) var groupedEntries: [(label: String, entries: [ClipboardEntry])] = []
    var selectedId: Int64? = nil

    // MARK: - Search

    var searchText: String = "" {
        didSet {
            searchDebounceTask?.cancel()
            searchDebounceTask = Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                await self.loadEntries()
            }
        }
    }
    private var searchDebounceTask: Task<Void, Error>?

    // MARK: - Private

    private let repository: ClipboardEntryRepository
    private let monitor: ClipboardMonitor
    private let classifier = ContentClassifier()
    private var monitorTask: Task<Void, Never>?

    init(repository: ClipboardEntryRepository = ClipboardEntryRepository(),
         monitor: ClipboardMonitor = ClipboardMonitor()) {
        self.repository = repository
        self.monitor = monitor
    }

    // MARK: - Lifecycle

    func start() {
        monitor.start()
        Task { await loadEntries() }
        monitorTask = Task { [weak self] in
            guard let self else { return }
            for await content in self.monitor.changes {
                await self.handleNewContent(content)
            }
        }
    }

    func stop() {
        monitor.stop()
        monitorTask?.cancel()
        monitorTask = nil
    }

    // MARK: - Actions

    func copy(entry: ClipboardEntry) {
        monitor.write(entry.content)
    }

    func delete(entry: ClipboardEntry) {
        guard let id = entry.id else { return }
        Task {
            try? await repository.delete(id: id)
            await loadEntries()
        }
    }

    func toggleFavorite(entry: ClipboardEntry) {
        guard let id = entry.id else { return }
        Task {
            try? await repository.toggleFavorite(id: id)
            await loadEntries()
        }
    }

    func copySelected() {
        guard let id = selectedId,
              let entry = groupedEntries.flatMap(\.entries).first(where: { $0.id == id })
        else { return }
        copy(entry: entry)
    }

    // MARK: - Private helpers

    @MainActor
    private func loadEntries() async {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        let fetched: [ClipboardEntry]
        if trimmed.isEmpty {
            fetched = (try? await repository.fetchRecent(limit: 100)) ?? []
        } else {
            fetched = (try? await repository.search(query: searchText)) ?? []
        }

        if !searchText.isEmpty {
            groupedEntries = fetched.isEmpty
                ? []
                : [(label: "\(fetched.count) result\(fetched.count == 1 ? "" : "s")", entries: fetched)]
        } else {
            groupedEntries = group(fetched)
        }
    }

    private func handleNewContent(_ content: String) async {
        guard let alreadyExists = try? await repository.exists(content: content),
              !alreadyExists else { return }
        let contentType = classifier.classify(content)
        let entry = ClipboardEntry(
            id: nil,
            content: content,
            contentType: contentType,
            createdAt: Date(),
            isFavorite: false
        )
        try? await repository.insert(entry)
        await loadEntries()
    }

    private func group(_ entries: [ClipboardEntry]) -> [(label: String, entries: [ClipboardEntry])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            return entries.isEmpty ? [] : [(label: String(localized: "Earlier"), entries: entries)]
        }

        var todayEntries: [ClipboardEntry] = []
        var yesterdayEntries: [ClipboardEntry] = []
        var earlierEntries: [ClipboardEntry] = []

        for entry in entries {
            let day = calendar.startOfDay(for: entry.createdAt)
            if day == today {
                todayEntries.append(entry)
            } else if day == yesterday {
                yesterdayEntries.append(entry)
            } else {
                earlierEntries.append(entry)
            }
        }

        var result: [(label: String, entries: [ClipboardEntry])] = []
        if !todayEntries.isEmpty     { result.append((label: String(localized: "Today"),     entries: todayEntries)) }
        if !yesterdayEntries.isEmpty { result.append((label: String(localized: "Yesterday"), entries: yesterdayEntries)) }
        if !earlierEntries.isEmpty   { result.append((label: String(localized: "Earlier"),   entries: earlierEntries)) }
        return result
    }
}
