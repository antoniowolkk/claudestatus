<p align="center">
  <img src="docs/icon.png" width="112" alt="Claude Status icon">
</p>

<h1 align="center">Claude Status</h1>

<p align="center">
  A light, futuristic macOS menu bar readout for <b>Claude Code</b>:<br>
  token usage, model, and which project folders Claude is working in — at a glance.
</p>

<p align="center">
  <img src="docs/panel.png" width="320" alt="Claude Status panel, light">
  &nbsp;
  <img src="docs/panel-dark.png" width="320" alt="Claude Status panel, dark">
</p>

Lives in your menu bar as a single icon — no text, no wasted space. Hover for a quick summary, click for the panel.

## Features

- **5-hour window** — tokens used in the current usage window, a ring showing time left (or % of your own budget), reset time and an estimated cost.
- **Session, today, 7 days** — token totals and estimated cost, plus today's cache hit rate.
- **Project you're in now** — the folder, git branch, model (Opus 5.5, Sonnet 5.5, …) and surface (CLI, desktop app, VS Code, JetBrains, Agent SDK).
- **Active projects** — every folder Claude worked in during the last 24 hours, newest first, with a live / active / idle dot, branch, worktree count and tokens. Claude Code worktrees and subfolders fold into their repo, so `AVIREO/.claude/worktrees/…` shows as **AVIREO**.
- **Setup wizard** — a terminal installer and a first-run window that checks everything for you.
- **Light or dark** — light by default, with a Dark mode switch in Settings. Your choice, not tied to the system setting.
- **Tiny** — native SwiftUI, about 1 MB, no Electron, no background services. Reads only new log lines after the first scan.
- **Private** — no network, no API keys, no telemetry. Runs in the App Sandbox.

## Requirements

- macOS 14 Sonoma or newer (Apple silicon or Intel)
- Xcode Command Line Tools (the installer offers to install them)
- [Claude Code](https://docs.claude.com/en/docs/claude-code) — the app reads its local logs

## Install

```bash
git clone https://github.com/antoniowolkk/claudestatus.git
cd claudestatus
./install.sh
```

The wizard walks through 7 steps:

| Step | What happens |
| --- | --- |
| 1. Check your Mac | macOS version and architecture |
| 2. Toolchain | Finds Swift; offers Apple's installer if it's missing |
| 3. Claude Code | Looks for `~/.claude/projects` and counts this week's sessions |
| 4. Location | `~/Applications` (no password) or `/Applications` |
| 5. Build | Compiles from source, signs with App Sandbox + hardened runtime |
| 6. Install | Replaces any running copy |
| 7. Launch | Opens the app; a setup window checks data access, dark mode and open at login |

Non-interactive: `./install.sh --yes` (installs to `~/Applications` and opens the app).

Update later with `git pull && ./install.sh`.

### Build by hand

```bash
scripts/build-app.sh               # → build/Claude Status.app
scripts/build-app.sh --universal   # Apple silicon + Intel (needs full Xcode)
```

## Use

Click the **✦** icon in the menu bar to open the panel (hover it for a one-line summary). From there:

- **↻** refreshes now (it also refreshes on its own every 20 seconds)
- **⚙** opens Settings
- **⏻** quits

### Settings

| Tab | Options |
| --- | --- |
| General | Dark mode, counting cache reads, a 5-hour token budget, refresh rate, open at login, rerun setup |
| Privacy | What the app reads and never does, and a shortcut to the logs folder |

### Active projects

Each row is one project with Claude activity in the last 24 hours:

| Dot | Meaning |
| --- | --- |
| Green · LIVE | Message in the last 2 minutes |
| Blue · ACTIVE | Message in the last 30 minutes |
| Gray | Idle; shows how long ago |

The highlighted row is the project you're in now. Hover a row to see its full path. Up to 6 projects are listed.

## How usage is counted

Claude Code writes one JSON line per message to `~/.claude/projects/<project>/<session>.jsonl`. Claude Status reads the assistant messages from the last 8 days and removes duplicates.

- **Tokens** = input + output + cache writes. Cache reads are left out by default because they're cheap and can be huge; turn them on in Settings.
- **5-hour window** starts at the hour of your first message and lasts 5 hours, the same way Claude plans count usage limits. A new window starts with the first message after it ends.
- **Cost** is an estimate from public Anthropic API list prices per model, including cache write and read rates. On a Pro or Max plan you aren't billed per token; treat it as a "what this would cost on the API" number.

## Security and privacy

| | |
| --- | --- |
| Network | None. The App Sandbox blocks all network access; the app has no network entitlement. |
| Files | Read-only access to `~/.claude/projects/`. Nothing else, enforced by the sandbox. |
| What's kept | Token counts, model, folder path, branch and surface, in memory only. Message text is discarded while parsing. |
| Writes | Only its own settings, inside its sandbox container. Never writes to `~/.claude`. |
| Secrets | No API keys, tokens or accounts. |
| Telemetry | None. |
| Install | Built from source on your Mac. No `curl \| bash`, no downloads, no `sudo` unless you choose `/Applications`. |
| Signing | Ad-hoc signed with hardened runtime. Set `SIGN_IDENTITY` to sign with your own Developer ID. |

Symlinks inside the logs folder are skipped and oversized log lines are dropped.

Found a security issue? See [SECURITY.md](SECURITY.md).

## Uninstall

```bash
./uninstall.sh
```

Asks before removing the app and its settings. Your Claude Code logs are never touched.

## Troubleshooting

**Nothing in the menu bar.** If you have many menu bar items, macOS hides the ones that don't fit. Quit a few, or hold ⌘ and drag icons to make room.

**"Logs not found".** Run a Claude Code session first. The app looks in `~/.claude/projects`.

**"Open at login" shows an error.** Move the app to `~/Applications` or `/Applications` first (the installer does this), then toggle it again.

**Branch shows "no branch".** The folder isn't a git repository, or Claude Code was on a detached HEAD.

## Project layout

```
Sources/ClaudeStatus/
  ClaudeStatusApp.swift   app entry, windows, login item
  StatusController.swift  menu bar item + instant, animation-free panel
  LogScanner.swift        incremental, read-only log parser + 5-hour windows
  UsageStore.swift        refresh loop and menu bar tooltip
  Pricing.swift           per-model price table for cost estimates
  PanelView.swift         menu bar panel
  SettingsView.swift      settings window
  OnboardingView.swift    first-run setup
  Theme.swift             colors, ring gauge, HUD cards
Resources/                Info.plist, entitlements, icon
scripts/                  build-app.sh, make-icon.swift
install.sh / uninstall.sh
```

Render the panel to a PNG without opening the menu bar (handy for docs):

```bash
.build/release/ClaudeStatus --snapshot panel.png --demo
```

---

Claude Status is an independent project and is not made by or affiliated with Anthropic.
