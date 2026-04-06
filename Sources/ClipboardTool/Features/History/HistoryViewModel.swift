import Foundation
import AppKit

@Observable
final class HistoryViewModel {

    // MARK: - State (read by View)

    private(set) var groupedEntries: [(label: String, entries: [ClipboardEntry])] = []
    var selectedId: Int64? = nil

    /// Forwarded from `ClipboardMonitor.isPaused` so the UI can bind to it.
    var isPaused: Bool { monitor.isPaused }

    /// Returns the currently selected entry without requiring a flatMap in the view body.
    var selectedEntry: ClipboardEntry? {
        guard let id = selectedId else { return nil }
        return groupedEntries.flatMap(\.entries).first { $0.id == id }
    }

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
    private var searchDebounceTask: Task<Void, Never>?

    // MARK: - Private

    private let repository: ClipboardEntryRepository
    private let collectionRepository: CollectionRepository
    private let monitor: ClipboardMonitor
    private let classifier = ContentClassifier()
    private var monitorTask: Task<Void, Never>?

    init(repository: ClipboardEntryRepository = ClipboardEntryRepository(),
         collectionRepository: CollectionRepository = CollectionRepository(),
         monitor: ClipboardMonitor = ClipboardMonitor()) {
        self.repository = repository
        self.collectionRepository = collectionRepository
        self.monitor = monitor
    }

    // MARK: - Lifecycle

    func start() {
        monitor.start()
        Task { [weak self] in
            guard let self else { return }
            await self.loadEntries()
        }
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
        Task { [weak self] in
            guard let self else { return }
            try? await repository.delete(id: id)
            await loadEntries()
        }
    }

    func toggleFavorite(entry: ClipboardEntry) {
        guard let id = entry.id else { return }
        Task { [weak self] in
            guard let self else { return }
            try? await repository.toggleFavorite(id: id)
            await loadEntries()
        }
    }

    /// Pauses clipboard monitoring. If `duration` is given, monitoring
    /// auto-resumes after that many seconds.
    func pauseMonitoring(for duration: TimeInterval? = nil) {
        monitor.pause(for: duration)
    }

    /// Resumes clipboard monitoring immediately.
    func resumeMonitoring() {
        monitor.resume()
    }

    func setAlias(id: Int64, alias: String?) {
        Task { [weak self] in
            guard let self else { return }
            try? await repository.updateAlias(id: id, alias: alias)
            await loadEntries()
        }
    }

    func setContentType(id: Int64, type: ContentType) {
        Task { [weak self] in
            guard let self else { return }
            try? await repository.updateContentType(id: id, contentType: type)
            await loadEntries()
        }
    }

    func reclassifyEntry(entry: ClipboardEntry) {
        guard let entryId = entry.id, !entry.manualOverride else { return }
        Task { [weak self] in
            guard let self else { return }
            let detected = classifier.classify(entry.content)
            if detected != entry.contentType {
                try? await repository.updateContentType(id: entryId, contentType: detected)
                try? await repository.clearManualOverride(id: entryId)
            }
            await loadEntries()
        }
    }

    func reclassifyAll() {
        Task { [weak self] in
            guard let self else { return }
            let all = (try? await repository.fetchAll()) ?? []
            for entry in all where !entry.manualOverride {
                guard let entryId = entry.id else { continue }
                let detected = classifier.classify(entry.content)
                if detected != entry.contentType {
                    try? await repository.updateContentType(id: entryId, contentType: detected)
                    // updateContentType sets manualOverride = true, so we clear it after
                    // by writing a second pass that preserves manualOverride = false.
                    try? await repository.clearManualOverride(id: entryId)
                }
            }
            await loadEntries()
        }
    }

    func copySelected() {
        guard let entry = selectedEntry else { return }
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
        let contentType: ContentType
        if content.hasPrefix("images/") {
            contentType = .image
        } else {
            contentType = classifier.classify(content)
        }
        let entry = ClipboardEntry(
            id: nil,
            content: content,
            contentType: contentType,
            createdAt: Date(),
            isFavorite: false
        )
        let savedEntry = try? await repository.insert(entry)
        if let savedEntry, let entryId = savedEntry.id {
            let rules = (try? await collectionRepository.fetchRules()) ?? []
            let collectionIds = matchingCollections(for: savedEntry, rules: rules)
            for colId in collectionIds {
                try? await collectionRepository.addEntry(entryId, to: colId)
            }
        }
        await loadEntries()
    }

    /// Returns unique collection IDs whose rules match `entry`.
    /// Rules must already be filtered to enabled and sorted by priority descending.
    private func matchingCollections(for entry: ClipboardEntry, rules: [CollectionRule]) -> [Int64] {
        var seen = Set<Int64>()
        var result: [Int64] = []

        for rule in rules {
            // Skip rules with neither condition set.
            guard rule.contentType != nil || rule.contentPattern != nil else { continue }

            let typeMatches: Bool
            if let ruleContentType = rule.contentType {
                typeMatches = entry.contentType.rawValue == ruleContentType
            } else {
                typeMatches = true
            }

            let patternMatches: Bool
            if let pattern = rule.contentPattern {
                let range = NSRange(entry.content.startIndex..., in: entry.content)
                let regex = try? NSRegularExpression(pattern: pattern)
                patternMatches = regex?.firstMatch(in: entry.content, range: range) != nil
            } else {
                patternMatches = true
            }

            guard typeMatches && patternMatches else { continue }

            let collectionId = rule.collectionId
            if seen.insert(collectionId).inserted {
                result.append(collectionId)
            }
        }

        return result
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
