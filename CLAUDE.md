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
| Label      | Use case                                      |
|------------|-----------------------------------------------|
| `feature`  | New capability or user-facing addition        |
| `fix`      | Corrects existing behavior (non-urgent)       |
| `hotfix`   | Urgent fix needing immediate attention        |
| `chore`    | Maintenance, deps, non-functional changes     |
| `refactor` | Code restructure without behavior change      |

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

## Agents

These are the roles Claude operates under depending on the task.
Each agent has a defined focus and constraints.

### 🏗 Architect
**Trigger:** Designing new features, discussing system structure, reviewing dependencies.
**Responsibilities:**
- Define module boundaries and data flow
- Ensure sandbox compatibility for future App Store submission
- Prevent tight coupling between Core, Database, and UI layers
- Review SPM dependencies before adding them

### 🍎 Swift Developer
**Trigger:** Writing or editing any `.swift` file.
**Responsibilities:**
- Follow Swift API Design Guidelines
- Use `@Observable` (not `ObservableObject`) for ViewModels
- Prefer `async/await` over callbacks or Combine
- No force unwraps (`!`) except in tests
- All NSPasteboard access must go through `ClipboardMonitor`
- All DB access must go through `DatabaseManager` repositories

### 🗄 Database Engineer
**Trigger:** Any change to GRDB models, migrations, or queries.
**Responsibilities:**
- Never modify existing migrations — always add new ones
- All models must conform to `FetchableRecord` + `PersistableRecord`
- Write indexes for all columns used in WHERE/ORDER BY
- Test queries with EXPLAIN QUERY PLAN before shipping

### 🎨 UI Engineer
**Trigger:** Any SwiftUI view or component work.
**Responsibilities:**
- Views are pure and stateless — all state lives in ViewModel
- Support Light and Dark mode via semantic colors only (never hardcode hex)
- All text must go through `Localizable.xcstrings` (en + es-MX)
- Minimum tap target: 44×44pt
- Use design tokens from `UI/Theme/` — no magic numbers

### 📦 Release Engineer
**Trigger:** Build, packaging, signing, or distribution tasks.
**Responsibilities:**
- Without Apple Developer account: build unsigned, instruct users to right-click → Open
- Sandbox entitlements must be declared before any new capability is used
- Sparkle feed URL must be kept up to date with each release
- When Apple Developer account is obtained: switch to Developer ID + notarization

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
