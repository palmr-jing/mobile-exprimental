# Deploy Status

**Deployment target:** TestFlight (App Store Connect app id `6780673334`).

**Build status:** App target builds and the test suites pass on the iPhone 17 Pro
simulator (see TEST_REPORT.md).

**Deployed:** No. No TestFlight upload was cut for this task.

This is a data-shape change to the "Report an issue" payload (adds `app`,
`app_platform`, `context`). Per CLAUDE.md, a TestFlight round-trip burns a build
number and must follow a full local suite run and a `CURRENT_PROJECT_VERSION` bump.
Ship it on the next planned build rather than a standalone upload:

1. `xcodegen generate`
2. `scripts/run-tests.sh` (or the mock-seam UITest command) — confirm green.
3. Bump `CURRENT_PROJECT_VERSION` in `project.yml`, commit to `main`.
4. `ASC_ISSUER_ID=<uuid> scripts/upload-testflight.sh`.

No web/hosting deploy applies to this repo.
