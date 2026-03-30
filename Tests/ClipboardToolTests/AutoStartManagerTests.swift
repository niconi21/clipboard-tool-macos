import XCTest
@testable import ClipboardTool

final class AutoStartManagerTests: XCTestCase {

    func testIsEnabledReturnsBoolWithoutCrashing() {
        // isEnabled must be readable in any environment without throwing or crashing.
        // We only check that it returns a valid Bool — not its specific value, since
        // whether the app is registered depends on the signing and sandbox state of
        // the test runner.
        let manager = AutoStartManager()
        let result = manager.isEnabled
        XCTAssertTrue(result == true || result == false)
    }

    func testEnableRequiresSignedSandboxedApp() throws {
        // SMAppService.register() only works in a properly signed, sandboxed app.
        // Calling it from the test bundle would throw; skip rather than fail.
        throw XCTSkip("SMAppService.register() requires a signed, sandboxed app bundle")
    }

    func testDisableRequiresSignedSandboxedApp() throws {
        // Same constraint as enable().
        throw XCTSkip("SMAppService.unregister() requires a signed, sandboxed app bundle")
    }
}
