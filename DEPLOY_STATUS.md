# Deploy Status — Task #1067 (Palmr watermarks)

Not a web deploy. This is the iOS app (bundle `ai.palmr.emma`); shipping is via
Xcode Archive → TestFlight (`scripts/upload-testflight.sh`), not a hosting target.
`firebase.json` here configures Firestore/Storage rules and emulators for tests,
not app hosting.

- **Build**: BUILD SUCCEEDED on iPhone 17 Pro (iOS 26.4).
- **Local test gate (CLAUDE.md)**: satisfied. Unit 75/75, `ReleasedUITests` 3/3,
  `VideosUITests` 7/7 on the simulator. See TEST_REPORT.md.
- **Release action**: **none performed.** The build number was deliberately NOT
  bumped and nothing was uploaded — an upload is outward-facing, burns a build
  number, and wasn't asked for. To ship:
  1. bump `CURRENT_PROJECT_VERSION` in `project.yml` (date stamp `YYYYMMDD.N`),
  2. `xcodegen generate`,
  3. `ASC_ISSUER_ID=<uuid> scripts/upload-testflight.sh`.
- **Backend impact**: none. No Firestore reads/writes, rules, or Storage paths
  changed. The watermark is rendered entirely on-device.
