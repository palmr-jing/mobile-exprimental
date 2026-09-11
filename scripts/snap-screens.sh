#!/bin/bash
# snap-screens.sh — build, install, and screenshot MobileCommander's signed-in UI.
# Output goes to shots/<name>.png.
#
# The app exposes a fake-auth seam (TestConfig: -UITEST / -FAKE_USER_EMAIL) so we
# can reach the signed-in UI without Google. It does NOT take per-tab launch args,
# so this script captures the launch + signed-in home screen; richer per-screen
# screenshots (sign-in, chat composer, etc.) are captured automatically by the
# XCUITest smoke phase in run-ios-e2e-and-publish.sh and exported from the
# .xcresult bundle.
#
# Usage: bash scripts/snap-screens.sh [SIM_UDID]
#   SIM_UDID defaults to the first booted iPhone simulator.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SHOTS_DIR="$REPO_DIR/shots"
DERIVED="${DERIVED_DATA_PATH:-/tmp/MobileCommander-DerivedData}"
BUNDLE_ID="ai.palmr.emma"
SCHEME="MobileCommander"

SIM_UDID="${1:-}"
if [ -z "$SIM_UDID" ]; then
  SIM_UDID=$(xcrun simctl list devices booted | awk -F '[()]' '/iPhone/ {print $2; exit}')
fi
if [ -z "$SIM_UDID" ]; then
  echo "No booted iPhone simulator and no UDID passed. Boot one (e.g. 'xcrun simctl boot \"iPhone 17 Pro\"') and retry."
  exit 1
fi

echo "Sim: $SIM_UDID"
mkdir -p "$SHOTS_DIR"

if command -v xcodegen >/dev/null 2>&1; then
  ( cd "$REPO_DIR" && xcodegen generate >/dev/null )
fi

APP="$DERIVED/Build/Products/Debug-iphonesimulator/$SCHEME.app"
if [ ! -d "$APP" ]; then
  echo "→ Building (first run, slow)..."
  xcodebuild -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=$SIM_UDID" \
    -derivedDataPath "$DERIVED" \
    build >/dev/null
fi

echo "→ Reinstall fresh"
xcrun simctl uninstall "$SIM_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIM_UDID" "$APP" >/dev/null

snap() {
  local name="$1"; shift
  echo "  $name"
  sleep "$1"
  xcrun simctl io "$SIM_UDID" screenshot "$SHOTS_DIR/$name.png" >/dev/null
}

echo "→ Launch (signed-in via fake auth) and snap"
xcrun simctl terminate "$SIM_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID" \
  -UITEST -FAKE_USER_EMAIL test@palmr.ai -FAKE_USER_ADMIN 1 >/dev/null
snap "01-home" 4

xcrun simctl terminate "$SIM_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
echo ""
echo "✓ wrote $(ls "$SHOTS_DIR"/*.png 2>/dev/null | wc -l | tr -d ' ') screenshot(s) to $SHOTS_DIR"
