# Test report — #1072 (Palmr logo + wordmark on Released videos)

## How to run

```sh
xcodegen generate

# Unit only (hermetic, fast)
SKIP_EMULATOR=1 scripts/run-tests.sh

# The suites touched by this task — no Firebase emulator needed, they run off
# the -MOCK_RELEASED / -MOCK_VIDEOS launch-arg fixtures.
xcodebuild test -scheme MobileCommander \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:MobileCommanderTests \
  -only-testing:MobileCommanderUITests/ReleasedUITests \
  -only-testing:MobileCommanderUITests/VideosUITests
```

## Status — all green, 2026-07-19

| Destination | Unit | UITests (Released + Videos) |
|---|---|---|
| iPhone 17 Pro (iOS 26.4) | 95 passed | 16 passed |
| iPad Air 11-inch M4 (iOS 26.4) | 95 passed | 16 passed |

Both runs exited 0 with `** TEST SUCCEEDED **`.

## What covers this change

### `Tests/Unit/WatermarkTests.swift` (rewritten)

The old tests asserted on #1067's design — a filled black pill behind system-font
text — so they had to be rewritten rather than extended. They now pin the mark to
manage's spec:

- `shipsManagesCombinedLogoAndWordmarkAsset` — the `PalmrLogoPair` raster is in
  the bundle and has the LogoPair's 3115×624 aspect. This is the gate that makes
  the pixel tests below meaningful: without it they could silently be asserting
  on the fallback wordmark.
- `stampsInManagesWarmWhite` — burned-in pixels are `#F1EDE3`, not plain white.
  The tell that the real asset was stamped and not recoloured.
- `drawsNoBackgroundPlateBehindTheMark` — the mark's box is >5% and <60% opaque.
  Fails if a plate is ever reintroduced (a pill would push it to ~100%).
- `burnInGeometryMatchesManage` — parameterised over three frame sizes; asserts
  width = 14% clamped [96,240], margin = 2% clamped [12,32], measured from the
  bottom-right, aspect preserved.
- `displayWidthFloorsOnSmallTilesAndScalesOnLargeOnes` — the displayed mark holds
  its 56pt legibility floor on a ~107pt angle tile, tracks 14% above that, caps
  at 240pt.
- `burnsIntoTheBottomRightAndLeavesTheRestUntouched`, `skipsFramesTooSmallToHoldIt…`,
  `zeroSizedCanvasIsANoOp` — carried over, thresholds adjusted for the plate-less
  mark.

### `Tests/UITests/ReleasedUITests.swift`

- `testFullSizeViewerIsWatermarked` (new) — the regression test for the actual
  report. Opens an angle full-size, waits for a real `angle-player`, and asserts
  a `palmr-watermark` exists bottom-trailing and inside the player's frame. It
  also attaches a screenshot (`.keepAlways`) so the branding can be eyeballed
  without re-driving the app.
- `testEveryAngleTileIsWatermarked` — unchanged assertions, now passing against
  the logo+wordmark mark rather than the mark-only badge.

**This test needed a playable offline fixture.** The `gtv-videos-bucket` sample
URLs in the `-MOCK_RELEASED` fixtures answer 403, so before this change no test
ever reached a live `AVPlayer` — the viewer always resolved to the "couldn't be
loaded" message, which is deliberately *not* branded. The first mock angle now
points at a bundled 3-second H.264 clip (`Resources/test-angle.mp4`, 2.9 KB,
generated with ffmpeg), so playback is exercised with no network.

## One flake found and fixed

Making those fixtures actually play surfaced a real bug. `AngleViewerView.start()`
activates an `AVAudioSession` to silence the ringer, and `teardown()` never
released it. No test had ever reached playback, so it had gone unnoticed. In a
back-to-back UITest run the app then hung on relaunch and XCTest reported
"Restarting after unexpected exit, crash, or test timeout" —
`testUnsupportedFormatDownloadShowsMessage` failed in sequence but passed in
isolation.

`teardown()` now deactivates the session with `.notifyOthersOnDeactivation`, off
the main thread. The suite has run clean on both devices since.

User-visible effect of the fix: closing the viewer no longer leaves the user's
music or podcast ducked.

## Screenshots

In `output/` (committed with `git add -f`):

- `released-tab-watermark.png` — iPhone, angle tiles.
- `released-viewer-watermark.png` — iPhone, full-size viewer (the bug surface).
- `released-viewer-watermark-ipad.png` — iPad, showing the mark scaling up on the
  larger surface.

## Not covered by automated tests

The burn-in path is asserted at the pixel level, but no test decodes an exported
`.mp4` and checks the mark survived the H.264 round-trip. `ReelExportTests`
covers that the overlay is composited; the mark's appearance in a finished export
is still eyeball-verified.
