# Deploy Status — Task #971

Not a web deploy. This is the iOS app (bundle `ai.palmr.emma`); shipping is via
Xcode Archive → TestFlight (`scripts/upload-testflight.sh`), not a hosting target.
`firebase.json` here configures Firestore/Storage rules and emulators for tests,
not app hosting.

- **Build**: BUILD SUCCEEDED — `xcodebuild build -scheme MobileCommander -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.
- **Release action**: none performed. To ship, bump `CURRENT_PROJECT_VERSION` in
  `project.yml`, run `xcodegen generate`, then `scripts/upload-testflight.sh`.
- **Firestore impact**: this change only *reads* the `released_recordings`
  collection; the app writes nothing new. The production read rule
  (`allow read: if request.auth != null`) already exists per the task brief. The
  vendored `firestore.rules` in this repo (emulator-only) gained a matching
  `released_recordings` read/write block so emulator-based tests can seed and read
  it — that file is NOT deployed from here (its source of truth lives in the
  commander repo).
