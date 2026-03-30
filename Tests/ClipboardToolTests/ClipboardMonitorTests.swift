import XCTest
@testable import ClipboardTool

// Integration tests that require a live NSPasteboard (i.e. an actual app
// environment with a window server connection) are skipped with XCTSkip.
// NSPasteboard.general is unavailable in the SPM test runner on macOS because
// there is no WindowServer session, so any test that calls changeCount or
// string(forType:) would crash or return garbage. Those scenarios are covered
// by manual / UI testing.
final class ClipboardMonitorTests: XCTestCase {

    // MARK: - Lifecycle

    func testStartDoesNotCrash() {
        let monitor = ClipboardMonitor()
        // start() must not throw or crash — minimal smoke test.
        monitor.start()
        monitor.stop()
    }

    func testStartIsIdempotent() {
        let monitor = ClipboardMonitor()
        // Calling start() twice while already running must be a no-op.
        monitor.start()
        monitor.start()
        monitor.stop()
    }

    func testStopBeforeStartDoesNotCrash() {
        let monitor = ClipboardMonitor()
        // stop() on a never-started monitor must be safe.
        monitor.stop()
    }

    func testStopIsIdempotent() {
        let monitor = ClipboardMonitor()
        monitor.start()
        monitor.stop()
        // Second stop must not crash.
        monitor.stop()
    }

    func testRestartAfterStop() {
        let monitor = ClipboardMonitor()
        monitor.start()
        monitor.stop()
        // Restarting must not crash.
        monitor.start()
        monitor.stop()
    }

    // MARK: - Stream lifecycle

    func testChangesStreamFinishesAfterStop() async throws {
        // NSPasteboard is unavailable in the SPM test runner (no WindowServer).
        // The stream itself should finish cleanly once stop() is called, but we
        // cannot reliably drive content through it without a real pasteboard.
        throw XCTSkip(
            "Requires a live NSPasteboard environment (WindowServer session). " +
            "Covered by manual / UI testing."
        )
    }

    func testChangesStreamDeduplicatesValues() async throws {
        // Would verify that identical consecutive clipboard values are not
        // re-emitted. Requires a live NSPasteboard to write values.
        throw XCTSkip(
            "Requires a live NSPasteboard environment (WindowServer session). " +
            "Covered by manual / UI testing."
        )
    }

    func testChangesStreamSkipsEmptyStrings() async throws {
        // Would verify that empty strings copied to the pasteboard are not
        // forwarded through the stream.
        throw XCTSkip(
            "Requires a live NSPasteboard environment (WindowServer session). " +
            "Covered by manual / UI testing."
        )
    }
}
