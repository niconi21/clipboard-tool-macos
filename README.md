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

- macOS 14 (Sonoma) or later
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

### Option B — Swift CLI ⚠️

> **Not recommended.** Dependencies use SwiftUI preview macros (`#Preview`) that require Xcode's build system. `swift build` from CLI will fail with macro plugin errors. Use Xcode instead.

## First run notes

- **Global hotkey:** on first use the system will ask for Accessibility permission. Grant it in System Settings → Privacy & Security → Accessibility.
- **At this stage** the app is a scaffold — the menu bar icon is functional but views are stubs pending implementation.

## Development tips

### Reset the database

To wipe all data and start fresh (useful during development):

```bash
rm ~/Library/Application\ Support/com.niconi21.clipboardtool/clipboard.db*
```

> Close the app before running this command. The three files (`clipboard.db`, `.db-shm`, `.db-wal`) are all part of SQLite's WAL mode — deleting them together resets the database completely. The migration will re-run and re-seed on next launch.

## Version

Current version is defined in `Package.swift` → `infoPlist` → `CFBundleShortVersionString`.
