# AGENTS Guide for `stash`

This file is for coding agents working in this repository.
Use it as the default project playbook unless higher-priority rules are added.

## 1) Cursor/Copilot Rule Files

- `.cursorrules`: not found.
- `.cursor/rules/`: not found.
- `.github/copilot-instructions.md`: not found.
- If any of these files appear later, treat them as higher priority than this document.

## 2) Project Snapshot

- App type: macOS menu bar utility built with Swift, SwiftUI, and AppKit.
- Entry point: `stash/stashApp.swift` (`@main` enum creating `NSApplication`).
- Primary target/scheme: `stash` / `stash`.
- Build configs: `Debug`, `Release`.
- Persistence: SQLite via raw `SQLite3` C API in `DatabaseManager`.
- Architecture style: AppDelegate-driven window/panel management + SwiftUI views.
- Deployment target in project file: macOS `26.1`.

## 3) Build / Lint / Test Commands

Run from repo root: `/Users/ayushsagar/Documents/GitHub/stash`.

### Build (Debug)

```bash
xcodebuild build \
  -project "stash.xcodeproj" \
  -scheme "stash" \
  -configuration Debug \
  -destination 'platform=macOS'
```

### Build (Release)

```bash
xcodebuild build \
  -project "stash.xcodeproj" \
  -scheme "stash" \
  -configuration Release \
  -destination 'platform=macOS'
```

### Clean

```bash
xcodebuild clean -project "stash.xcodeproj" -scheme "stash"
```

### Lint/static checks

No SwiftLint/SwiftFormat config is currently present.
Use compiler warnings and analyzer output as the lint gate:

```bash
xcodebuild analyze \
  -project "stash.xcodeproj" \
  -scheme "stash" \
  -configuration Debug \
  -destination 'platform=macOS'
```

### Tests (current status)

- `xcodebuild test` currently fails: `Scheme stash is not currently configured for the test action.`
- There is no test target in `stash.xcodeproj/project.pbxproj` yet.

### Test command template (when tests are added)

```bash
xcodebuild test \
  -project "stash.xcodeproj" \
  -scheme "stash" \
  -destination 'platform=macOS'
```

### Run a single test (important)

Use `-only-testing:TargetName/TestCaseName/testMethodName`:

```bash
xcodebuild test \
  -project "stash.xcodeproj" \
  -scheme "stash" \
  -destination 'platform=macOS' \
  -only-testing:stashTests/AppStateTests/testAddTask
```

You can pass multiple focused tests by repeating `-only-testing:`.

## 4) Code Style Guidelines

### Imports

- Keep imports explicit and minimal; remove unused imports.
- Prefer Apple frameworks only unless a dependency is explicitly requested.
- One import per line; no wildcard patterns.

### Formatting and structure

- Use 4-space indentation; no tabs.
- Prefer one primary type per file.
- Use `// MARK: - ...` to split meaningful sections.
- Keep functions small; use `guard` and early returns over deep nesting.

### Types and concurrency

- Prefer `final class` unless inheritance is needed.
- Use `@MainActor` for UI-facing types and state containers.
- Keep data models `Sendable` where relevant.
- If using `@unchecked Sendable`, ensure thread safety is explicit (e.g., private serial queue).

### State management

- Treat `AppState` as the source of truth for task collections and overlay mode.
- Route mutations through `AppState` methods (`addTask`, `completeTask`, `promoteTask`, etc.).
- Refresh derived state after writes (`reload`, `reloadCompleted`).
- Use local `@State` only for transient view concerns.

### Naming conventions

- Types/protocols: `UpperCamelCase`.
- Properties/methods/variables: `lowerCamelCase`.
- Enum cases: `lowerCamelCase` (e.g., `.l1`, `.mem`).
- Favor intent-revealing names over abbreviations.

### Error handling and logging

- Prefer explicit handling over silent failure when user impact exists.
- Use `guard` for invalid state and early exits.
- Log concise context-prefixed messages (existing style uses `[Stash] ...`).
- Avoid `fatalError` in runtime code paths.

### Database and persistence

- Keep SQLite operations serialized through `DatabaseManager.queue`.
- Always finalize prepared statements.
- Keep SQL column mapping aligned with `StashTask` fields.

### SwiftUI + AppKit boundaries

- Keep panel/window lifecycle logic in AppKit layer (`AppDelegate`, panel/controller types).
- Keep SwiftUI views declarative and callback-driven.
- Pass behavior through closures rather than hard-coding cross-layer dependencies.

## 5) Agent Checklist

- Build after non-trivial edits using the Debug build command.
- Run `analyze` when touching threading, AppKit lifecycle, or DB logic.
- If tests are added, run targeted `-only-testing` first, then broader runs.
- Avoid introducing new warnings in touched code.
- Do not add new tooling/config files unless explicitly asked.
