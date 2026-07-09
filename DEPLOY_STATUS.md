# Deploy Status — Task #947

Not a web deploy. This is the iOS app (bundle `ai.palmr.emma`); shipping is via
Xcode Archive → TestFlight (`scripts/upload-testflight.sh`), not a hosting target.
`firebase.json` here configures Firestore/Storage rules and emulators for tests,
not app hosting.

- **Build**: BUILD SUCCEEDED — `xcodebuild build -scheme MobileCommander -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` (app target); test build + unit suite also pass.
- **Release action**: none performed. To ship, bump `CURRENT_PROJECT_VERSION` in
  `project.yml` and run `scripts/upload-testflight.sh`.
- **Firestore impact**: read-only change. The message listener now queries with an
  `order(by: createdAt, descending) + limit` instead of an unbounded ascending read.
  No schema, rules, or write-shape changes. Reads are smaller (a page at a time) rather
  than the full channel history, so this reduces Firestore read volume on chat open.
