import AppKit
import SwiftUI

extension NSApplication {
    func relaunch() {
        let url = Bundle.main.bundleURL
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = [url.path]
        try? task.run()
        terminate(nil)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var hotkeyManager: HotkeyManager?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock — menu bar only
        NSApp.setActivationPolicy(.accessory)

        setupMenuBar()

        hotkeyManager = HotkeyManager(onToggle: { [weak self] in
            self?.togglePopover()
        })
        hotkeyManager?.register()

        // Show onboarding on very first launch
        if !UserDefaults.standard.bool(forKey: "onboardingCompleted") {
            showOnboarding()
        }
    }

    func showOnboarding() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "Welcome to ClipboardTool")
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        window.setFrameAutosaveName("OnboardingWindow")

        let onboardingView = OnboardingView {
            self.onboardingWindow?.close()
            self.onboardingWindow = nil
        }

        window.contentViewController = NSHostingController(rootView: onboardingView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipboardTool")
            button.action = #selector(togglePopover)
            button.target = self
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 480)
        popover.behavior = .transient
        popover.animates = true

        popover.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .ignoresSafeArea()
                .environment(\.closePopover, { [weak popover] in
                    popover?.performClose(nil)
                })
        )
        self.popover = popover
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
