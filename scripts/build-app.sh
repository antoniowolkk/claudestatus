#!/usr/bin/env bash
# Builds "Wolkky Claude Status.app" into ./build. No network access needed after the toolchain is installed.
#
#   scripts/build-app.sh              native architecture
#   scripts/build-app.sh --universal  Apple silicon + Intel (needs full Xcode)
#
# Env: SIGN_IDENTITY="Developer ID Application: ..." to sign with your own certificate.
#      Default is ad-hoc signing (fine for running on your own Mac).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="Wolkky Claude Status"
APP="$ROOT/build/$APP_NAME.app"
ARCH_FLAGS=()
if [[ "${1:-}" == "--universal" ]]; then
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

echo "→ Compiling (release)…"
swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"

echo "→ Assembling app bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/ClaudeStatus" "$APP/Contents/MacOS/ClaudeStatus"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "→ Signing (sandbox + hardened runtime)…"
codesign --force --options runtime --timestamp=none \
  --entitlements "$ROOT/Resources/ClaudeStatus.entitlements" \
  --sign "${SIGN_IDENTITY:--}" "$APP"
codesign --verify --strict "$APP"

echo "✓ Built: $APP"
