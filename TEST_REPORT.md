# Test Report — Task #971 (read `released_recordings`, show class recordings)

## Build Status
- **Platform**: iOS Simulator — iPhone 17 Pro (iOS 26.x)
- **Status**: BUILD SUCCEEDED (`xcodebuild build -scheme MobileCommander -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`)

## Tests

### Unit Tests (`Tests/Unit/`)
- **ReleasedRecordingTests.swift** — NEW, 10 cases covering the `released_recordings` parser + sort:
  - `parsesReleasedClassWithGroupedAngles` — decodes plan_id/class/device and keeps all 3 camera angles grouped under one doc.
  - `mapsCameraLabels` — `front` / `front-right` / `realsense` → `Front` / `Front-right` / `RealSense`.
  - `nullRoomBecomesNilAndIsOmittedFromLabel` / `roomWhenPresentJoinsDeviceLabel` — `room: null` handling and the "device · room" label.
  - `angleCountFallsBackToVideoCount` / `angleCountDecodesFromDouble` — `angle_count` as missing / Double.
  - `invalidDownloadURLBecomesNilAngle` — empty/invalid `download_url` decodes to a nil URL (rendered as an "Unavailable" tile, not a crash).
  - `rejectsDocWithNoClassAndNoAngles` / `keepsDocWithAnglesButNoClassLabel` — empty-doc rejection vs. angle-only survival.
  - `sortsNewestFirstByReleasedAtThenStartsAt` — newest-first by `released_at`, falling back to `starts_at` when `released_at` is missing.
- Other suites (AccessTests, ChatPaginationTests, ChatShareTests, PresenceTests, VideoTests, ReelExportTests, ReportIssueTests, SpeechRecognitionServiceTests) — unchanged, still pass.

## How to Run
```bash
# Unit tests only (hermetic, no emulator):
SKIP_EMULATOR=1 scripts/run-tests.sh

# Just the new suite:
xcodebuild test -scheme MobileCommander \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:MobileCommanderTests/ReleasedRecordingTests
```

## Current Status
- **Unit tests**: ALL PASS. The new `ReleasedRecordingTests` suite is 10/10 green; the full `MobileCommanderTests` target still passes.
- **Simulator run**: launched on iPhone 17 Pro with `-MOCK_RELEASED`. The **Released** tab lists the card "IMA Fit + Tiny Tigers" (Jul 10, 2026, `everbot-lubancat-2`) with its 3 grouped angles (Front / Front-right / RealSense). Tapping a tile swaps it to an inline `VideoPlayer` — verified via Maestro tap + screenshot.
- **Live Firestore**: NOT exercised here — that needs an interactive Google sign-in the autonomous run can't perform. The live listener path mirrors the existing, shipping `VideoService`/`FirestoreService` snapshot pattern.

## Notes
- The `FirebaseFirestore … Could not reach Cloud Firestore backend` lines during the unit run are expected: unit tests are hermetic and don't connect to a backend.
- The `-MOCK_RELEASED` fixtures point at Google's public sample MP4s so the inline player has something to play in the simulator; production reads tokenized `download_url`s straight from Firestore.
