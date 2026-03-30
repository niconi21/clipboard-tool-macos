# clipboard-tool-macos — Project Context

Native macOS clipboard manager. Menu bar app built with Swift + SwiftUI.
Mirror project of [clipboard-tool](https://github.com/niconi21/clipboard-tool) (Linux/Windows, Tauri), rewritten from scratch for macOS using native Apple APIs.

---

## Tech Stack

| Component       | Technology                          |
|-----------------|-------------------------------------|
| Language        | Swift 5.9+                          |
| UI              | SwiftUI + MenuBarExtra               |
| Clipboard       | NSPasteboard polling                 |
| Database        | GRDB (SQLite)                        |
| Global hotkeys  | KeyboardShortcuts (sindresorhus)     |
| Auto-start      | SMAppService                         |
| Auto-update     | Sparkle 2 (direct dist only)         |
| Min target      | macOS 14 (Sonoma)                    |

## Distribution

- **Now:** Developer ID signing or unsigned (right-click → Open). No Apple Developer account yet.
- **Future:** App Store (sandbox already enabled from day 1 to avoid refactor).

---

## Architecture

```
ClipboardTool/
├── App/
│   ├── ClipboardToolApp.swift       # @main, MenuBarExtra, app lifecycle
│   └── AppDelegate.swift            # NSApplicationDelegate hooks
├── Core/
│   ├── ClipboardMonitor.swift       # NSPasteboard polling service
│   ├── ContentClassifier.swift      # Detects URLs, emails, code, colors, phones
│   └── HotkeyManager.swift          # KeyboardShortcuts wrapper
├── Database/
│   ├── DatabaseManager.swift        # GRDB pool setup
│   ├── Models/
│   │   ├── ClipboardEntry.swift     # Main history model
│   │   ├── Collection.swift         # User-defined groups
│   │   └── Favorite.swift           # Pinned entries
│   └── Migrations.swift             # GRDB migrations
├── Features/
│   ├── History/
│   │   ├── HistoryView.swift
│   │   └── HistoryViewModel.swift
│   ├── Search/
│   │   ├── SearchView.swift
│   │   └── SearchViewModel.swift
│   ├── Collections/
│   │   ├── CollectionsView.swift
│   │   └── CollectionsViewModel.swift
│   └── Settings/
│       ├── SettingsView.swift
│       └── SettingsViewModel.swift
├── UI/
│   ├── Components/                  # Reusable SwiftUI views
│   ├── Theme/                       # Colors, typography, spacing tokens
│   └── MenuBarView.swift            # Root popover view
└── Resources/
    ├── Assets.xcassets
    └── Localizable.xcstrings        # en + es-MX
```

### Pattern: MVVM + Services

- **Views** — SwiftUI only, zero business logic
- **ViewModels** — `@Observable`, bind to views, call services
- **Services** (Core/) — business logic, no UI dependency
- **Database** — GRDB, accessed only through repository pattern

---

## GitHub Workflow

**Repo:** https://github.com/niconi21/clipboard-tool-macos
**Board:** https://github.com/users/niconi21/projects/41

### Issue labels

Every issue must have **at minimum** these three label categories:
1. **Version** — `v1.0.0`, `v1.1.0`, etc. (read from `Supporting/Info.plist`)
2. **Type** — one of the type labels below
3. **Area** — one or more area labels (use multiple if the issue spans several layers)

Do **not** show the word "area" anywhere in issues — just use the label names directly.

| Label        | Category | Use case                                      |
|--------------|----------|-----------------------------------------------|
| `feature`    | type     | New capability or user-facing addition        |
| `fix`        | type     | Corrects existing behavior (non-urgent)       |
| `hotfix`     | type     | Urgent fix needing immediate attention        |
| `chore`      | type     | Maintenance, deps, non-functional changes     |
| `refactor`   | type     | Code restructure without behavior change      |
| `clipboard`  | area     | NSPasteboard monitoring and capture           |
| `ui`         | area     | SwiftUI views and design system               |
| `database`   | area     | GRDB, migrations, queries                     |
| `core`       | area     | Business logic services (Core/)               |
| `collections`| area     | Collections and favorites                     |
| `settings`   | area     | Settings window and preferences               |
| `search`     | area     | Search and filtering                          |
| `localization`| area    | i18n strings                                  |
| `distribution`| area    | Build, signing, distribution                  |

### Status flow
```
Backlog → Todo → In Progress → In Validation → Done
                                             ↘ Dependencie
```
- Issues start at **Backlog**
- Claude moves to **In Progress** before starting work
- Claude moves to **In Validation** when done
- Human decides: **Done** or **Dependencie**

---

## Definition of Done

Before moving any issue to **In Validation**, the following must be met:

1. **Tests** — every new function/repository/service must have unit tests covering the happy path and key edge cases. Tests live in `Tests/ClipboardToolTests/`.
2. **Build** — the project must compile without errors in Xcode (⌘B).
3. **Tests pass** — all tests must pass (⌘U). No new failures allowed.
4. **No new warnings** — warnings that would be errors in Swift 6 must be fixed before closing the issue.

If any of the above fails, the issue stays **In Progress** until resolved.

---

## Agents

Defined in `.claude/agents/` — each agent has its own file with tools, triggers and constraints.

| Agent | File | Trigger |
|---|---|---|
| 🏗 Architect | `.claude/agents/architect.md` | Structure, modules, dependencies |
| 🍎 Swift Developer | `.claude/agents/swift-developer.md` | Any `.swift` file |
| 🗄 Database Engineer | `.claude/agents/database-engineer.md` | GRDB, migrations, queries |
| 🎨 UI Engineer | `.claude/agents/ui-engineer.md` | SwiftUI views, design system |
| 📦 Release Engineer | `.claude/agents/release-engineer.md` | Builds, signing, distribution |

---

## Key Decisions Log

| Decision | Reason |
|---|---|
| Sandbox enabled from day 1 | Avoid refactor when submitting to App Store |
| macOS 14 minimum | Access to `@Observable`, `MenuBarExtra` + `SMAppService` |
| GRDB over Core Data | Type-safe SQL, easier migrations, no ObjC runtime |
| KeyboardShortcuts over CGEventTap | Handles sandbox + accessibility permissions cleanly |
| Sparkle for updates | Standard for non-App Store macOS apps |
| No Apple Developer account (for now) | Distribution via right-click → Open, sufficient for beta |
