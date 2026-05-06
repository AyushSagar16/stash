# Stash

A cache-tier to-do app for macOS. Tasks live in three tiers — **L1** (next hour), **L2** (next 3–5 hours), and **L3** (sometime in the future) — accessed by a Spotlight-style overlay summoned with a double-tap of Control.

The visual is Spotlight; the input semantics are terminal. You type commands, hit Enter, hit Esc.

## Build

```sh
./scripts/build.sh           # debug build → ./Stash.app
./scripts/build.sh release
open Stash.app               # launch the daemon
```

## First-run setup (do this once)

The daemon is invisible — no Dock icon, no menu bar icon. Two one-time grants:

### 1. Accessibility (so the hotkey works)
The first time you launch, macOS asks for Accessibility permission. If you missed the prompt:

- **System Settings → Privacy & Security → Accessibility**
- Toggle **Stash** on
- Restart Stash: `pkill -x Stash && open Stash.app`

Without this, the global double-Control hotkey will not fire.

### 2. Install to `/Applications` (so launch-at-login persists across reboots)

`SMAppService` registers a LaunchAgent pointing at the current bundle path. If you keep `Stash.app` in this project folder, the LaunchAgent will get a stale path the next time you rebuild. To make it permanent:

```sh
cp -R Stash.app /Applications/
open /Applications/Stash.app
```

System Settings → General → Login Items will show **Stash** under "Open at Login".

## Usage

### Summon / dismiss

| Action | Shortcut |
|---|---|
| Show overlay | Tap **Control** twice (within ~300ms) |
| Hide overlay | `Esc` or click outside |
| Toggle from a script | `kill -USR1 $(pgrep -x Stash)` |

### Commands

| Command | Effect |
|---|---|
| `1 "title"`, `2 "title"`, `3 "title"` | quick-add to L1/L2/L3 |
| `add l1\|l2\|l3 "title" [#tag] [@time]` | long form |
| `done <id>` | mark complete (id is a 3-char prefix like `a3f`) |
| `mv <id> l1\|l2\|l3` | move tiers |
| `rm <id>` | delete |
| `tag <id> <tag>` | add a tag |
| `ls` | list all tiers (always visible too) |
| `clear l1\|l2\|l3` | empty a tier |
| `find <query>` | fuzzy search across tiers + history |
| `every monday "title"` | recurring weekly |
| `daily "title"` | recurring daily |
| `history` | last 7 days of completed |
| `help` | show all commands |
| `q` / `esc` | hide overlay |
| `quit` | kill the daemon |

`@time` examples: `@4pm`, `@5:30am`, `@9pm`, `@tomorrow`. `#tag` is inline (`add l1 "review pr" #work`).

Tab autocompletes commands and task ids. ↑/↓ recalls input history within the current overlay session.

### Cache mechanics

- **Auto-promotion**: an L2 task whose due time enters the next hour automatically slides into L1 (background scan every 60s).
- **Overdue**: L1 tasks past their due time stay in L1 with an `overdue` marker — they don't auto-demote.
- **History retention**: completed tasks are pruned after 7 days.
- **Recurring**: when a task with a recurrence rule is marked done, the next instance is materialized.

## Troubleshooting

```sh
# Is it running?
pgrep -lf Stash.app

# What is it logging?
log show --predicate 'subsystem == "com.stash.app"' --info --last 5m --style compact

# Where's the data?
ls ~/Library/Application\ Support/stash/

# Force-toggle overlay (works even before Accessibility is granted)
kill -USR1 $(pgrep -x Stash)

# Stop
pkill -x Stash

# Unregister launch-at-login
launchctl print gui/$UID/com.stash.app           # inspect
osascript -e 'tell application "Stash" to quit'  # if it ignores pkill
```

## Project layout

```
Stash/
├── Window/         OverlayPanel, VisualEffectView, HotkeyMonitor
├── Views/          ContentView, CommandLineView, TierSectionView, TaskRowView
├── Model/          StashTask (@Model), Tier, TaskStore
├── Commands/       Command, CommandParser, CommandRunner, Suggestions, InputHistory
├── Services/       PromotionTimer, NotificationScheduler, HistoryPruner,
│                   RecurrenceMaterializer, LaunchAgent
└── Theme/          Palette
```

Resources/Info.plist sets `LSUIElement=true` so the daemon never appears in Dock or Cmd-Tab.
