# Deploy Status — #1076

**Target:** TestFlight (iOS app `ai.palmr.emma`, ASC app id 6780673334).

**Build status:** Compiles clean; unit suite passes on the iPhone 17 Pro
simulator (101 tests, 12 suites).

**Deployed:** No. This run did not archive or upload to TestFlight, and did not
bump `CURRENT_PROJECT_VERSION`. Per CLAUDE.md a TestFlight round-trip is
expensive and should be an explicit human step. The fix is committed on the task
branch.

**To ship:** bump `CURRENT_PROJECT_VERSION` in `project.yml`, commit to `main`,
then `ASC_ISSUER_ID=<uuid> scripts/upload-testflight.sh`. Confirm on a real
device that picking a video in Ask Emma attaches (see FOLLOW_UP.md) before
relying on it.
