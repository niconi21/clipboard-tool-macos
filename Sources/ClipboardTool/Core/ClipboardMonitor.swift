import AppKit
import Foundation

// Monitors NSPasteboard for changes and publishes new string content.
// All NSPasteboard access in the app must go through this service — never
// read NSPasteboard directly from views or view models.
//
// Usage:
//   let monitor = ClipboardMonitor()
//   monitor.start()
//   for await text in monitor.changes {
//       print("New clipboard content:", text)
//   }
//   monitor.stop()
final class ClipboardMonitor {

    // MARK: - Public API

    /// Emits each new, non-empty, deduplicated string read from NSPasteboard.
    var changes: AsyncStream<String> {
        AsyncStream { continuation in
            streamContinuation = continuation
        }
    }

    /// Starts the polling loop. Safe to call multiple times — subsequent calls
    /// while already running are no-ops.
    func start() {
        guard pollingTask == nil else { return }
        pollingTask = Task.detached(priority: .utility) { [weak self] in
            await self?.runPollingLoop()
        }
    }

    /// Writes a string to the pasteboard.
    /// Updates internal state so the next poll does not re-capture the same content.
    func write(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        // Advance lastChangeCount so readIfChanged skips this write on the next poll.
        lastChangeCount = NSPasteboard.general.changeCount
        // Treat the written value as already emitted to suppress a duplicate yield.
        lastEmittedValue = string
    }

    /// Stops the polling loop and finishes the `changes` stream.
    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        streamContinuation?.finish()
        streamContinuation = nil
    }

    // MARK: - Private

    private var pollingTask: Task<Void, Never>?
    private var streamContinuation: AsyncStream<String>.Continuation?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var lastEmittedValue: String?

    private static let pollingInterval: Duration = .milliseconds(500)

    private func runPollingLoop() async {
        while !Task.isCancelled {
            readIfChanged()
            try? await Task.sleep(for: Self.pollingInterval)
        }
    }

    // Isolated to avoid data races: all mutable state is accessed on the
    // actor that owns this instance, but since ClipboardMonitor is not an
    // actor we keep mutation local to this single Task.detached call path.
    private func readIfChanged() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let text = pasteboard.string(forType: .string),
              !text.isEmpty,
              text != lastEmittedValue else { return }

        lastEmittedValue = text
        streamContinuation?.yield(text)
    }
}
