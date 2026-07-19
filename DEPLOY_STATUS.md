# Deploy Status — Task #1063

Not a web deploy. This is the iOS app (bundle `ai.palmr.emma`); shipping is via Xcode Archive →
TestFlight (`scripts/upload-testflight.sh`), not a hosting target. `firebase.json` here configures
Firestore/Storage rules and emulators for tests, not app hosting.

- **Build**: BUILD SUCCEEDED / TEST SUCCEEDED on the iOS Simulator (iPhone 17 Pro, iOS 26.4).
  72 unit + 11 UITests green. See TEST_REPORT.md — it must be run against an isolated simulator and
  `-derivedDataPath`, because a concurrent worktree was colliding on the shared ones.
- **Release action**: **none performed — no TestFlight upload.** CLAUDE.md's gate (local sim suite
  passing first) is satisfied, so this is ready to ship, but an upload burns a build number and
  wasn't part of the ask. To ship:
  1. Bump `CURRENT_PROJECT_VERSION` in `project.yml` — still `20260717.1` from #1049, and a repeat
     build number is rejected by App Store Connect.
  2. `xcodegen generate`
  3. `ASC_ISSUER_ID=<uuid> scripts/upload-testflight.sh`
- **Firestore/Storage impact**: none. This change only alters how the client *renders* an angle that
  fails to play. No schema change, no new writes, no rules change.
- **Backend dependency**: the underlying cause is likely producer-side (missing `download_url`, or
  WebM emitted by the release pipeline in everbot-manage). That fix ships from a different repo — see
  FOLLOW_UP.md.
