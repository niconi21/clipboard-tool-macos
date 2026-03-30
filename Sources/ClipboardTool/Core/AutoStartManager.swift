import Foundation
import ServiceManagement

// Wraps SMAppService to enable or disable launch-at-login.
// State is read directly from SMAppService — no local storage needed.
struct AutoStartManager {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func enable() throws {
        try SMAppService.mainApp.register()
    }

    func disable() throws {
        try SMAppService.mainApp.unregister()
    }
}
