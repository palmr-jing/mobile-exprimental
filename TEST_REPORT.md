# Test Report — Task #760 (fix all-white/unreadable text)

## What exists
- **Unit tests** (`Tests/Unit`, Swift Testing): hermetic, no emulator. Cover Access
  rules and Presence/roster/mention logic — 20 tests across 2 suites.
- **UI tests** (`Tests/UITests`, XCUITest): run against the Firebase Local Emulator
  Suite, seeded by `scripts/seed-emulator.mjs`.

## How to run
```bash
# Unit only (hermetic):
DEST="platform=iOS Simulator,name=<your simulator>" SKIP_EMULATOR=1 scripts/run-tests.sh

# Unit + UI/E2E (needs firebase CLI + emulator):
DEST="platform=iOS Simulator,name=<your simulator>" scripts/run-tests.sh
```

## Status — PASS
- **Build**: `xcodebuild build -scheme MobileCommander -destination 'generic/platform=iOS Simulator'`
  → **BUILD SUCCEEDED** (Firebase + GoogleSignIn SPM resolved clean).
- **Unit tests**: 20/20 passed (AccessTests 8, PresenceTests 12).
- **UI/E2E**: not run in this session (requires the Firebase emulator + live seed).
  This change is appearance-only and does not touch the data/UI-test paths.

## Manual verification of the fix
- Created an iPhone 16 Pro simulator (iOS 26.4), set system appearance to **dark**
  (`simctl ui <udid> appearance dark`) — the exact condition that produced the
  white-text bug — then installed and launched the app.
- Login-screen screenshot showed the light cream background with **dark, readable
  text** and a dark status-bar clock, confirming the app forces light appearance
  regardless of the device's dark-mode setting.
- The lock is global (Info.plist `UIUserInterfaceStyle=Light` +
  `.preferredColorScheme(.light)` on the root), so every screen — including the
  Ask Emma and Chat inputs that previously rendered white-on-light — resolves text
  to the dark token in dark mode.
- Confirmed the built app bundle's `Info.plist` reports `UIUserInterfaceStyle = Light`.

## Not verified (needs human)
- Post-login screens (Dashboard, Chat, Ask Emma thread) require real Google auth,
  which can't run headless. The fix is global appearance, so these inherit it, but
  a human should sign in on a dark-mode device and eyeball each screen + type into
  both chat composers to confirm input text is dark.
