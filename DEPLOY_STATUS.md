# Deploy Status — Task #1049

Not a web deploy. This is the iOS app (bundle `ai.palmr.emma`); shipping is via
Xcode Archive → TestFlight (`scripts/upload-testflight.sh`), not a hosting target.
`firebase.json` here configures Firestore/Storage rules and emulators for tests,
not app hosting.

- **Build**: BUILD SUCCEEDED — `xcodebuild test -scheme MobileCommander -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` (compiles the app + runs the suites).
- **Release action**: none performed. To ship, bump `CURRENT_PROJECT_VERSION` in
  `project.yml`, run `xcodegen generate`, then `scripts/upload-testflight.sh`.
- **Firestore/Storage impact**: none. This change is client-only — it reads the
  existing `commander_videos` docs and changes how the player reacts to an
  undecodable video. No rules, schema, or writes changed.
- **Cross-repo note**: the durable fix that makes these reels actually play is in
  `everbot-manage` (emit/transcode MP4 instead of WebM) and is NOT part of this
  deploy. See FOLLOW_UP.md.
