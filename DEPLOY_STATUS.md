# Deploy Status — Task #1038

Not a web deploy. This is the iOS app (bundle `ai.palmr.emma`); shipping is via
Xcode Archive → TestFlight (`scripts/upload-testflight.sh`), not a hosting target.

- **Build**: BUILD SUCCEEDED + TEST SUCCEEDED — `xcodebuild test -scheme MobileCommander -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:MobileCommanderTests`.
- **Release action**: none performed. To ship, bump `CURRENT_PROJECT_VERSION` in
  `project.yml`, run `xcodegen generate`, then `scripts/upload-testflight.sh`.
- **Firestore impact**: this change adds a *write* to `commander_tasks` (filing a
  ticket for a dropped Emma request). It uses the same create shape and access
  rule (`allow create: if request.auth != null && canAccessProject(project)`, with
  `project == "mobile commander"`) as the already-shipping "Report an issue" flow,
  so no rules change is needed. No `firestore.rules` edit in this task.
