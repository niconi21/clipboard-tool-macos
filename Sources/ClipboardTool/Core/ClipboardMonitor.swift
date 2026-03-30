import AppKit
import Foundation

// Monitors NSPasteboard for changes and publishes new string content.
// All NSPasteboard access in the app must go through this service — never
// read NSPasteboard directly from views or view models.
//
// Adaptive polling:
//   - 0.3 s when there was clipboard activity in the last 5 seconds (active)
//   - 1.0 s when idle (no activity for 5+ seconds)
//
// Self-copy prevention:
//   Calling write(_:) advances the internal change counter and marks a
//   pending-skip flag. The very next change detection caused by that write
//   is suppressed so the app's own paste-back is not stored as a new entry.
//
// Pause / resume:
//   isPaused == true keeps the polling loop alive but skips change detection.
//   pause(for:) optionally schedules an automatic resume after a duration.
//
// Usage:
//   let monitor = ClipboardMonitor()
//   monitor.start()
//   for await text in monitor.changes {
//       print("New clipboard content:", text)
//   }
//   monitor.stop()
@Observable
final class ClipboardMonitor {

    // MARK: - Public state

    /// True while monitoring is paused. Observed by views / view-models.
    private(set) var isPaused: Bool = false

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
    /// Advances internal state so the next poll does not re-capture the same
    /// content (self-copy prevention).
    func write(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        // Advance lastChangeCount so readIfChanged recognises this change.
        lastChangeCount = NSPasteboard.general.changeCount
        // Suppress the one detection event this write will generate.
        skipNextDetection = true
        // Treat the written value as already emitted to prevent duplicate yield.
        lastEmittedValue = string
    }

    /// Pauses change detection. The polling loop continues running.
    /// - Parameter duration: If provided, monitoring auto-resumes after this
    ///   many seconds. Pass `nil` to pause indefinitely.
    func pause(for duration: TimeInterval? = nil) {
        isPaused = true
        resumeTask?.cancel()
        resumeTask = nil
        if let duration {
            resumeTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(duration))
                guard !Task.isCancelled else { return }
                self?.resume()
            }
        }
    }

    /// Resumes change detection immediately.
    func resume() {
        isPaused = false
        resumeTask?.cancel()
        resumeTask = nil
    }

    /// Stops the polling loop and finishes the `changes` stream.
    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        resumeTask?.cancel()
        resumeTask = nil
        streamContinuation?.finish()
        streamContinuation = nil
    }

    // MARK: - Private

    private var pollingTask: Task<Void, Never>?
    private var resumeTask: Task<Void, Never>?
    private var streamContinuation: AsyncStream<String>.Continuation?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var lastEmittedValue: String?

    // Adaptive polling intervals
    private static let activeInterval: Duration = .milliseconds(300)
    private static let idleInterval: Duration = .milliseconds(1000)
    private static let activityWindowSeconds: TimeInterval = 5

    // Timestamp of the last observed clipboard change (used for adaptive interval)
    private var lastActivityDate: Date?

    // Self-copy prevention: when true, the very next changeCount transition is skipped
    var skipNextDetection: Bool = false

    private func runPollingLoop() async {
        while !Task.isCancelled {
            if !isPaused {
                readIfChanged()
            }
            let interval = currentInterval()
            try? await Task.sleep(for: interval)
        }
    }

    private func currentInterval() -> Duration {
        guard let lastActivity = lastActivityDate else {
            return Self.idleInterval
        }
        let elapsed = Date().timeIntervalSince(lastActivity)
        return elapsed < Self.activityWindowSeconds ? Self.activeInterval : Self.idleInterval
    }

    // Isolated to avoid data races: all mutable state is accessed on the
    // actor that owns this instance, but since ClipboardMonitor is not an
    // actor we keep mutation local to this single Task.detached call path.
    private func readIfChanged() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        // Self-copy prevention: skip the detection event caused by write(_:).
        if skipNextDetection {
            skipNextDetection = false
            return
        }

        // Record activity for adaptive polling regardless of content filtering.
        lastActivityDate = Date()

        // Text takes priority. Check it first.
        if let text = pasteboard.string(forType: .string),
           !text.isEmpty,
           text != lastEmittedValue {
            lastEmittedValue = text
            streamContinuation?.yield(text)
            return
        }

        // No text — check for an image.
        let canReadImage = pasteboard.canReadObject(
            forClasses: [NSImage.self],
            options: nil
        )
        guard canReadImage,
              let image = pasteboard.readObjects(
                  forClasses: [NSImage.self],
                  options: nil
              )?.first as? NSImage else { return }

        // Store image on disk (dedup by SHA-256 hash).
        guard let relativePath = try? ImageStore().store(image: image) else { return }
        // relativePath is nil when the image is already stored (dedup).
        lastEmittedValue = relativePath
        streamContinuation?.yield(relativePath)
    }
}
