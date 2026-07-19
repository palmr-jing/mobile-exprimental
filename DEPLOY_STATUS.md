# Deploy status — Task #1064

Not a web deploy. This is the iOS app (bundle `ai.palmr.emma`); shipping is Xcode
Archive → TestFlight via `scripts/upload-testflight.sh`. The `firebase.json` here
configures Firestore/Storage rules and test emulators, not app hosting.

- **Build**: BUILD SUCCEEDED — `xcodebuild test -scheme MobileCommander -destination 'platform=iOS Simulator,name=iPhone 17e'` (build + full test run).
- **Release action**: **none performed.** No build number bump, no archive, no upload.
  The change is committed on `task/1064-ios-i-want-to-be-able-to-click-on-one-of` only.
- **To ship**: bump `CURRENT_PROJECT_VERSION` in `project.yml` (date stamp `YYYYMMDD.N`,
  currently `20260717.1`), `xcodegen generate`, then `ASC_ISSUER_ID=<uuid> scripts/upload-testflight.sh`.
  The local-test gate CLAUDE.md requires is already satisfied — see TEST_REPORT.md.
- **Backend impact**: none. This change only reads `download_url` values the Released tab
  already had, and writes to the device's Photos library. No Firestore reads/writes added,
  no rules change, no new permission string (`NSPhotoLibraryAddUsageDescription` was
  already in `Resources/Info.plist` for the reel editor).
