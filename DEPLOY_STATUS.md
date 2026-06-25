# Deploy Status — Task #835

Not a web deploy. This is the iOS app (bundle `ai.palmr.emma`); shipping is via
Xcode Archive → TestFlight (`scripts/upload-testflight.sh`), not a hosting target.
`firebase.json` here configures Firestore/Storage rules and emulators for tests,
not app hosting.

- **Build**: BUILD SUCCEEDED — `xcodebuild build-for-testing -scheme MobileCommander -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` (app + both test targets).
- **Release action**: none performed. To ship, bump `CURRENT_PROJECT_VERSION` in
  `project.yml` and run `scripts/upload-testflight.sh`.
- **Firestore impact**: this change writes a new `replyTo` map on chat message
  documents. No rules change is needed — message creation is already permitted by
  `firestore.rules`, and `replyTo` is an additional field on an existing write.
