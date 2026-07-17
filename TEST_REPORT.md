# Test Report — Task #1049 ([iOS] Reel 30 clips doesn't play when clicked on)

## Build Status
- **Platform**: iOS Simulator — iPhone 17 Pro (iOS 26.x)
- **Status**: BUILD SUCCEEDED (`xcodebuild test -scheme MobileCommander -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`)

## Tests

### Unit Tests (`Tests/Unit/`) — Swift Testing, hermetic
- **VideoTests.swift** — 2 NEW cases for the unsupported-format detector:
  - `flagsBrowserComposedWebMAsUnsupported` — a Firebase download URL whose
    percent-encoded path ends in `.webm` (past `?alt=media&token=…`), a plain
    `.mkv` URL, and a `.webm` storage path all flag as unsupported.
  - `doesNotFlagPlayableFormats` — `.mp4` (URL + storage path), `.mov`, and a
    source-less video are NOT flagged.
- Full unit target: **67 tests / 9 suites — ALL PASS.** Existing suites
  (AccessTests, ChatPaginationTests, ChatShareTests, PresenceTests, VideoTests,
  ReleasedRecordingTests, ReelExportTests, ReportIssueTests,
  SpeechRecognitionServiceTests) unchanged and green.

### UI Tests (`Tests/UITests/VideosUITests.swift`) — XCUITest, offline via `-MOCK_VIDEOS`
- **testUnsupportedFormatReelShowsMessage** — NEW. Reproduces the report: taps the
  WebM "Reel · 30 clips" mock, asserts the `reel-failed` message appears (instead
  of a black frame), closes, and returns to the grid. **PASS.**
- Existing 6 cases (grid render, tap-routing, open/close cycling, non-overlap,
  report sheet, share sheet) — unchanged and green. **7/7 PASS** (118.6s).

## How to Run
```bash
# Unit tests only (hermetic, no emulator):
SKIP_EMULATOR=1 scripts/run-tests.sh

# The Videos-tab UI tests (offline mock, no emulator needed):
xcodebuild test -scheme MobileCommander \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:MobileCommanderUITests/VideosUITests
```

## Current Status
- **Unit**: 67/67 pass. **VideosUITests**: 7/7 pass.
- **Behavior verified end-to-end**: opening the WebM reel now shows a clear
  "not a format iOS can play" message and the feed chrome (close) still works —
  driven and observed via XCUITest, not just asserted in code.

## Notes / Limitations
- This change makes the app fail gracefully; it does NOT make the WebM reel play.
  iOS has no native WebM/VP9 decoder. The durable fix (emit/transcode MP4) is
  producer-side in `everbot-manage` — see FOLLOW_UP.md.
- The `FirebaseFirestore … Could not reach Cloud Firestore backend` lines during
  the unit run are expected: unit tests are hermetic and don't hit a backend.
- Live-Firestore playback of a real released reel was not exercised (needs an
  interactive Google sign-in this autonomous run can't perform); the fix is
  format-driven and covered by the mock reproduction above.
