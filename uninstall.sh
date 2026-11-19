#!/usr/bin/env bash
# Removes Wolkky Claude Status. Your Claude Code logs are never touched.
set -euo pipefail

APP_NAME="Wolkky Claude Status"
BUNDLE_ID="com.antoniowolkk.claudestatus"

ask() {
  local reply
  read -r -p "  $1 [y/N] " reply || true
  [[ "${reply:-n}" =~ ^[Yy] ]]
}

echo
echo "  Wolkky Claude Status uninstaller"
echo

osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
pkill -f "$APP_NAME.app/Contents/MacOS/ClaudeStatus" >/dev/null 2>&1 || true

for dir in "$HOME/Applications" "/Applications"; do
  for name in "$APP_NAME" "Claude Status"; do
    if [[ -d "$dir/$name.app" ]]; then
      if ask "Remove $dir/$name.app?"; then
        if [[ -w "$dir" ]]; then rm -rf "$dir/$name.app"; else sudo rm -rf "$dir/$name.app"; fi
        echo "  ✓ Removed $dir/$name.app"
      fi
    fi
  done
done

CONTAINER="$HOME/Library/Containers/$BUNDLE_ID"
if [[ -d "$CONTAINER" ]] && ask "Remove app settings ($CONTAINER)? This can't be undone."; then
  rm -rf "$CONTAINER"
  echo "  ✓ Removed settings"
fi


echo
echo "  Done. ~/.claude was not touched."
echo
