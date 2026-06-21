# Deploy Status — Task #760

Not applicable as a web deploy. This is the iOS app (bundle `ai.palmr.emma`);
shipping is via Xcode Archive → TestFlight (`scripts/upload-testflight.sh`), not a
hosting target. `firebase.json` in this repo configures Firestore/Storage rules and
emulators for tests, not app hosting.

- **Build**: BUILD SUCCEEDED — `xcodebuild build -scheme MobileCommander -destination 'generic/platform=iOS Simulator'`.
- **Install/launch**: verified on an iPhone 16 Pro simulator (iOS 26.4) in dark mode.
- **Release action**: none performed. Bump `CURRENT_PROJECT_VERSION` in `project.yml`
  and run `scripts/upload-testflight.sh` when ready to ship.
