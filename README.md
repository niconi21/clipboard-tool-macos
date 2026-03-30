# clipboard-tool-macos

Native macOS clipboard manager built with Swift + SwiftUI.

## Stack

| Component | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI | SwiftUI + NSPopover |
| Clipboard | NSPasteboard |
| Database | GRDB (SQLite) |
| Menu bar | NSStatusItem + NSPopover |
| Global hotkeys | KeyboardShortcuts (sindresorhus) |
| Auto-start | SMAppService |
| Auto-update | Sparkle 2 |

## Features

- Searchable clipboard history stored locally (SQLite)
- Content classification: URLs, emails, code, colors, phone numbers
- Menu bar presence — always one click away
- Global hotkey to open/close
- Favorites and collections
- Auto-start on login
- Light / Dark mode support

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15+

## Running the app

### Option A — Xcode (recommended)

1. Clone the repo:
   ```bash
   git clone https://github.com/niconi21/clipboard-tool-macos.git
   cd clipboard-tool-macos
   ```

2. Open the project in Xcode by double-clicking `Package.swift`, or from the terminal:
   ```bash
   open Package.swift
   ```
   Xcode will resolve SPM dependencies automatically (GRDB, KeyboardShortcuts, Sparkle).

3. Select the `ClipboardTool` scheme and your Mac as the destination, then press **⌘R** to build and run.

4. The app has no Dock icon — look for the clipboard icon (⌘) in your **menu bar**.

### Option B — Swift CLI

```bash
swift build
.build/debug/ClipboardTool
```

> The app will appear in your menu bar, not in the Dock. If you don't see it, check that your menu bar isn't full (macOS hides icons when there's no space).

## First run notes

- **Global hotkey:** on first use the system will ask for Accessibility permission. Grant it in System Settings → Privacy & Security → Accessibility.
- **At this stage** the app is a scaffold — the menu bar icon is functional but views are stubs pending implementation.

## Version

Current version is defined in `Sources/ClipboardTool/Resources/Info.plist` → `CFBundleShortVersionString`.

```bash
/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Sources/ClipboardTool/Resources/Info.plist
```
