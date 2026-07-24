# Test Report — report provenance (app id + context)

## What exists

- **Unit (Swift Testing) — `Tests/Unit/ReportIssueTests.swift`**
  - `titleIsPrefixedAndClippedFromFirstLine` (pre-existing)
  - `bodyNamesTheTabAndTheAttachedScreenshot` (pre-existing)
  - `tabOnlyContextCarriesTheTab` (new) — `{ tab }`-only context.
  - `recordingContextCarriesTheClassIdentity` (new) — recording context fields.
  - `recordingFirestoreValueFlattensAndOmitsAbsentFields` (new) — Firestore-safe
    scalars, absent optionals omitted.
- **UITest (XCUITest, mock seam) — `Tests/UITests/ReleasedUITests.swift`**
  - `testViewerReportOpensTheReportSheet` (new) — the recording viewer's "Report an
    issue" button opens the report sheet offline over the viewer.

## How to run

```sh
# Unit suite only (hermetic, no emulator):
xcodebuild test -scheme MobileCommander \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:MobileCommanderTests

# The new viewer UITest (offline, mock seam — no Firebase):
xcodebuild test -scheme MobileCommander \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:MobileCommanderUITests/ReleasedUITests
```

## Status — PASS (iPhone 17 Pro simulator, 2026-07-24)

- Unit: **130 tests in 15 suites passed** (`** TEST SUCCEEDED **`). The three new
  `ReportIssueTests` cases each passed.
- UITest: **`ReleasedUITests` 14/14 passed**, plus the new
  `testViewerReportOpensTheReportSheet` passed on its own run.

## Not covered

- `ReportIssuePresenter.submit(...)` writes to live Firestore (`addDocument` +
  Storage), so the actual `app`/`app_platform`/`context` write is not asserted
  end-to-end on the simulator. The payload shape is locked by the unit tests above;
  the submission code path is unchanged from before this task.
