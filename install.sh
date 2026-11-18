#!/usr/bin/env bash
# Claude Status install wizard.
#
#   ./install.sh          interactive
#   ./install.sh --yes    accept defaults (install to ~/Applications, open app)
#
# What it does: checks your Mac, builds the app from this folder's source,
# copies it to an Applications folder and opens it. No downloads, no sudo
# unless you pick /Applications and it isn't writable.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Claude Status"
BUNDLE_ID="com.antoniowolkk.claudestatus"
YES=0
[[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]] && YES=1

# ── Styling ────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  B=$'\033[1m'; D=$'\033[2m'; C=$'\033[38;5;39m'; G=$'\033[38;5;42m'; Y=$'\033[38;5;214m'; R=$'\033[38;5;203m'; N=$'\033[0m'
else
  B=""; D=""; C=""; G=""; Y=""; R=""; N=""
fi
step=0
header() { step=$((step + 1)); printf "\n${C}${B}[%02d]${N} ${B}%s${N}\n" "$step" "$1"; }
ok()     { printf "     ${G}✓${N} %s\n" "$1"; }
warn()   { printf "     ${Y}!${N} %s\n" "$1"; }
fail()   { printf "     ${R}✗${N} %s\n" "$1"; exit 1; }
note()   { printf "     ${D}%s${N}\n" "$1"; }

ask() { # ask "Question" default(y/n)
  local q="$1" def="${2:-y}" reply
  if [[ $YES -eq 1 ]]; then [[ "$def" == "y" ]]; return; fi
  local hint="[Y/n]"; [[ "$def" == "n" ]] && hint="[y/N]"
  read -r -p "     $q $hint " reply || true
  reply="${reply:-$def}"
  [[ "$reply" =~ ^[Yy] ]]
}

choose() { # choose "Question" opt1 opt2 … → echoes picked option
  local q="$1"; shift
  local opts=("$@") i reply
  if [[ $YES -eq 1 ]]; then echo "${opts[0]}"; return; fi
  printf "     %s\n" "$q" >&2
  for i in "${!opts[@]}"; do printf "       ${C}%d${N}) %s\n" $((i + 1)) "${opts[$i]}" >&2; done
  read -r -p "     Choice [1]: " reply || true
  reply="${reply:-1}"
  [[ "$reply" =~ ^[0-9]+$ ]] && (( reply >= 1 && reply <= ${#opts[@]} )) || reply=1
  echo "${opts[$((reply - 1))]}"
}

printf "\n${C}${B}  ✦  C L A U D E  //  S T A T U S${N}\n"
printf "${D}     Menu bar token usage + active projects for Claude Code${N}\n"

# ── 1. System ──────────────────────────────────────────────────────────────
header "Checking your Mac"
[[ "$(uname -s)" == "Darwin" ]] || fail "macOS only."
OS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
(( OS_MAJOR >= 14 )) || fail "macOS 14 Sonoma or newer required (you have $(sw_vers -productVersion))."
ok "macOS $(sw_vers -productVersion) on $(uname -m)"

# ── 2. Toolchain ───────────────────────────────────────────────────────────
header "Checking the Swift toolchain"
if ! xcode-select -p >/dev/null 2>&1 || ! command -v swift >/dev/null 2>&1; then
  warn "Xcode Command Line Tools are not installed."
  if ask "Open Apple's installer now?" y; then
    xcode-select --install || true
    note "Finish the Apple installer, then run ./install.sh again."
  fi
  exit 1
fi
ok "$(swift --version 2>/dev/null | head -1 | sed 's/^.*Apple Swift/Swift/' | cut -c1-40)"

# ── 3. Claude Code logs ────────────────────────────────────────────────────
header "Looking for Claude Code"
LOGS="$HOME/.claude/projects"
if [[ -d "$LOGS" ]]; then
  COUNT="$(find "$LOGS" -name '*.jsonl' -type f -mtime -7 2>/dev/null | wc -l | tr -d ' ')"
  ok "Found logs in ~/.claude/projects ($COUNT session files this week)"
else
  warn "No ~/.claude/projects yet. The app will start showing data after your first Claude Code session."
fi

# ── 4. Location ────────────────────────────────────────────────────────────
header "Choosing where to install"
DEST_CHOICE="$(choose "Install to:" "$HOME/Applications (just you, no password)" "/Applications (all users)")"
if [[ "$DEST_CHOICE" == /Applications* ]]; then DEST="/Applications"; else DEST="$HOME/Applications"; fi
mkdir -p "$DEST" 2>/dev/null || true
SUDO=""
if [[ ! -w "$DEST" ]]; then
  warn "$DEST needs admin rights. You'll be asked for your password once."
  SUDO="sudo"
fi
ok "$DEST/$APP_NAME.app"

# ── 5. Build ───────────────────────────────────────────────────────────────
header "Building the app"
note "Compiles from source in this folder. Takes about a minute the first time."
LOG="$(mktemp -t claudestatus-build)"
if ! "$ROOT/scripts/build-app.sh" >"$LOG" 2>&1; then
  tail -20 "$LOG"
  fail "Build failed. Full log: $LOG"
fi
rm -f "$LOG"
ok "Built and signed (App Sandbox, hardened runtime)"

# ── 6. Install ─────────────────────────────────────────────────────────────
header "Installing"
if pgrep -f "$APP_NAME.app/Contents/MacOS/ClaudeStatus" >/dev/null 2>&1; then
  osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || pkill -f "$APP_NAME.app/Contents/MacOS/ClaudeStatus" || true
  sleep 1
  note "Closed the running copy."
fi
$SUDO rm -rf "$DEST/$APP_NAME.app"
$SUDO ditto "$ROOT/build/$APP_NAME.app" "$DEST/$APP_NAME.app"
ok "Copied to $DEST"

# ── 7. Launch ──────────────────────────────────────────────────────────────
header "Done"
if ask "Open Claude Status now?" y; then
  open "$DEST/$APP_NAME.app"
  ok "Look for ✦ in your menu bar. The setup window walks you through the rest."
else
  note "Open it any time from $DEST."
fi
printf "\n     ${D}Uninstall: ./uninstall.sh${N}\n\n"
