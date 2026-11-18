#!/usr/bin/env bash
# Removes Claude Status. Your Claude Code logs are never touched.
set -euo pipefail

APP_NAME="Claude Status"
BUNDLE_ID="com.antoniowolkk.claudestatus"

ask() {
  local reply
  read -r -p "  $1 [y/N] " reply || true
  [[ "${reply:-n}" =~ ^[Yy] ]]
}

echo
echo "  Claude Status uninstaller"
echo

osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
pkill -f "$APP_NAME.app/Contents/MacOS/ClaudeStatus" >/dev/null 2>&1 || true

for dir in "$HOME/Applications" "/Applications"; do
  if [[ -d "$dir/$APP_NAME.app" ]]; then
    if ask "Remove $dir/$APP_NAME.app?"; then
      if [[ -w "$dir" ]]; then rm -rf "$dir/$APP_NAME.app"; else sudo rm -rf "$dir/$APP_NAME.app"; fi
      echo "  ✓ Removed $dir/$APP_NAME.app"
    fi
  fi
done

CONTAINER="$HOME/Library/Containers/$BUNDLE_ID"
if [[ -d "$CONTAINER" ]] && ask "Remove app settings ($CONTAINER)? This can't be undone."; then
  rm -rf "$CONTAINER"
  echo "  ✓ Removed settings"
fi


echo
echo "  Done. ~/.claude was not touched."
echo
