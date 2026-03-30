import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePopover = Self("togglePopover")
}

// Registers and handles the global hotkey to toggle the popover.
final class HotkeyManager {
    private let onToggle: () -> Void

    init(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle

        // Set ⌘⇧V as default only if the user hasn't customized it yet
        if KeyboardShortcuts.getShortcut(for: .togglePopover) == nil {
            KeyboardShortcuts.setShortcut(.init(.v, modifiers: [.command, .shift]), for: .togglePopover)
        }
    }

    func register() {
        KeyboardShortcuts.onKeyUp(for: .togglePopover) { [weak self] in
            self?.onToggle()
        }
    }

    func unregister() {
        KeyboardShortcuts.removeHandler(for: .togglePopover)
    }
}
