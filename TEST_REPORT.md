# Test Report — Task #1063 (Released tab: tapped angles never load)

## Build Status
- **Platform**: iOS Simulator — iPhone 17 Pro (iOS 26.4)
- **Status**: BUILD SUCCEEDED / TEST SUCCEEDED

⚠️ **Run with an isolated simulator + DerivedData.** Another worktree (`task-1064`) was running
`xcodebuild` against the shared `iPhone 17 Pro` device and shared DerivedData at the same time.
That collision produced *false* failures — "Lost connection to the application", app restarts, and
a log that listed test names belonging to the other branch. Isolating fixed it:

```bash
DEV=$(xcrun simctl create "sim-1063" "iPhone 17 Pro")
xcodebuild test -scheme MobileCommander \
  -destination "platform=iOS Simulator,id=$DEV" \
  -derivedDataPath /tmp/dd-1063 \
  -only-testing:MobileCommanderTests \
  -only-testing:MobileCommanderUITests/ReleasedUITests \
  -only-testing:MobileCommanderUITests/VideosUITests
xcrun simctl delete "$DEV"   # cleanup
```

## Results — all green

| Suite | Count | Status |
|---|---|---|
| `MobileCommanderTests` (unit, 9 suites) | 72 | PASS |
| `MobileCommanderUITests/ReleasedUITests` | 4 | PASS |
| `MobileCommanderUITests/VideosUITests` | 7 | PASS |

Unit count went 67 → 72 (5 new cases).

### New unit cases — `Tests/Unit/ReleasedRecordingTests.swift`
Cover `ReleasedRecording.Angle.isLikelyUnsupportedFormat`, the detector that lets a tile explain
itself instead of going black:
- `flagsWebMAngleAsUnsupported` / `treatsMP4AngleAsSupported` — the basic discrimination.
- `readsExtensionThroughFirebaseDownloadURL` — the extension is still readable through a
  percent-encoded Storage path *and* a `?alt=media&token=…` query string.
- `fallsBackToStoragePathExtension` — works off `storage_path` when `download_url` is absent.
- `angleWithNoSourceIsNotFlaggedAsUnsupported` — no source is "unavailable", not "bad format";
  the two render different messages.

### New UI cases — `Tests/UITests/ReleasedUITests.swift`
Both run offline off `-MOCK_RELEASED`; no Firestore, no Storage, no network.
- `testUnsupportedFormatAngleShowsMessage` — **this is the regression test for the report.** Taps a
  WebM angle and asserts the failure element appears. Fails against the old code (the tap left a
  permanently black tile).
- `testAngleWithNoSourceShowsUnavailable` — an angle released with no URL says "Not available"
  rather than rendering as an inert black rectangle.

Two notes on how these are written:
- They query `app.descendants(matching: .any)`, not `app.otherElements`. SwiftUI does not surface
  an `.accessibilityElement(children: .combine)` container as `otherElements` here — the
  type-specific query misses the element and the test fails for the wrong reason. Confirmed by
  dumping the hierarchy.
- The new mock card is appended **last** on purpose. `testReleasedShowsCards` asserts one-row
  geometry over `angle-play` buttons via `prefix(3)`; prepending would silently retarget that
  assertion at the wrong card.

## Manual verification on the simulator
Installed the built `.app` on the isolated device with `-UITEST -MOCK_RELEASED` and captured both
states (`output/released-failure-states-after.png`):
- Tapping the WebM angle renders **"Format not supported on iOS"** — previously a black tile forever.
- The source-less angle renders **"Not available"** with a `video.slash` glyph.
- The two fully-playable MP4 cards are unchanged and still show their play buttons.

## Not covered
- **Live Firestore/Storage** — needs an interactive Google sign-in this run can't perform. The
  specific real-world case in the user's screenshot (an *expired or 403 tokenized Storage URL*) is
  handled by the `AVURLAsset.load(.isPlayable)` probe, which is exercised in code but not against a
  genuinely expired token. See FOLLOW_UP.md — this is the main thing to confirm on the device.
- **Firebase emulator UITests** — `scripts/run-tests.sh` skips them (no global `firebase` CLI, per
  CLAUDE.md). The mock-seam tests above cover this change without it.
