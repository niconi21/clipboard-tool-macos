import XCTest
@testable import ClipboardTool

final class HotkeyManagerTests: XCTestCase {

    func testInitDoesNotCrash() {
        // Verifies that constructing a HotkeyManager with a closure succeeds
        var called = false
        let manager = HotkeyManager(onToggle: { called = true })
        XCTAssertNotNil(manager)
        // onToggle must not fire at init time
        XCTAssertFalse(called)
    }

    func testRegisterAndUnregisterLifecycle() {
        // Verifies that register() and unregister() can be called without crashing
        let manager = HotkeyManager(onToggle: {})
        manager.register()
        manager.unregister()
    }

    func testMultipleRegisterCallsDoNotCrash() {
        // Calling register() more than once must be safe
        let manager = HotkeyManager(onToggle: {})
        manager.register()
        manager.register()
        manager.unregister()
    }

    func testUnregisterWithoutRegisterDoesNotCrash() {
        // Calling unregister() before register() must be safe
        let manager = HotkeyManager(onToggle: {})
        manager.unregister()
    }

    func testActualHotkeyFiring() throws {
        // Firing the real global hotkey requires a running WindowServer session,
        // which is not available in the test environment.
        throw XCTSkip("Requires a running app / WindowServer — cannot be tested headlessly")
    }
}
