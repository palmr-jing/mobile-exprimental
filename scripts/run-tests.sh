#!/usr/bin/env bash
# Run the iOS test suites, mirroring the web's `npm test` + E2E runner.
#   - Unit tests (Swift Testing): hermetic, no emulator needed.
#   - UI tests (XCUITest): run against the Firebase Local Emulator Suite, seeded
#     with scripts/seed-emulator.mjs, so E2E never touches the live fleet.
#
# Usage:
#   scripts/run-tests.sh            # unit + UI tests
#   SKIP_EMULATOR=1 scripts/run-tests.sh   # unit tests only
#   DEST="platform=iOS Simulator,name=iPhone 17 Pro" scripts/run-tests.sh
set -euo pipefail
cd "$(dirname "$0")/.."

DEST="${DEST:-platform=iOS Simulator,name=iPhone 17 Pro}"
# Must match the app's Firebase project (GoogleService-Info.plist). The app is
# hardwired to fir-web-codelab-8ace9, so the emulator + seed must run under the
# same id — otherwise the app's Firestore streams hit a project the emulator was
# not started for and every Firestore-backed UITest fails with a stream error.
PROJECT_ID="${PROJECT_ID:-fir-web-codelab-8ace9}"

echo "▸ Generating Xcode project…"
xcodegen generate >/dev/null

echo "▸ Unit tests…"
xcodebuild test \
  -scheme MobileCommander \
  -destination "$DEST" \
  -only-testing:MobileCommanderTests \
  | grep -E "Test run|✔|✘|error:" || true

if [[ "${SKIP_EMULATOR:-0}" == "1" ]]; then
  echo "▸ SKIP_EMULATOR=1 — skipping UI/E2E tests."
  echo "✓ Unit suite complete."
  exit 0
fi

if ! command -v firebase >/dev/null 2>&1; then
  echo "⚠ firebase CLI not found (npm i -g firebase-tools). Skipping UI/E2E tests."
  exit 0
fi

echo "▸ UI tests under the Firebase emulator…"
firebase emulators:exec \
  --only auth,firestore,storage \
  --project "$PROJECT_ID" \
  "node scripts/seed-emulator.mjs && \
   xcodebuild test \
     -scheme MobileCommander \
     -destination \"$DEST\" \
     -only-testing:MobileCommanderUITests \
     | grep -E 'Test Case|passed|failed|error:' || true"

echo "✓ All suites complete."
