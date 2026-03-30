# clipboard-tool-macos

Native macOS clipboard manager built with Swift + SwiftUI.

## Stack

| Component | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI | SwiftUI |
| Clipboard | NSPasteboard |
| Database | GRDB (SQLite) |
| Menu bar | NSStatusItem + NSPopover |
| Global hotkeys | NSEvent global monitor |
| Auto-start | SMAppService |

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

## Development

Open `ClipboardTool.xcodeproj` in Xcode and run the scheme `ClipboardTool`.
