# Test Report — Task #1067 (Palmr watermarks)

## Build Status
- **Platform**: iOS Simulator — iPhone 17 Pro (iOS 26.4)
- **Status**: BUILD SUCCEEDED

## What was tested

### Unit — `Tests/Unit/WatermarkTests.swift` (NEW, 6 cases)
Pixel-level assertions on the rendered mark, because "is the branding actually in
the frame" is only answerable in pixels:
- `burnsIntoTheBottomRightAndLeavesTheRestUntouched` — the mark lands in the
  bottom-right quadrant and the other three quadrants are byte-identical to the
  source. Catches both a missing mark and one that drifts over the footage.
- `scalesWithTheFrameSoItReadsAtAnyResolution` — coverage stays the same order of
  magnitude at 320×568 and 1080×1920, so it can't ship as a speck on a real reel.
- `skipsFramesTooSmallToHoldItRatherThanDrawingItClipped` — a 40×30 frame is left
  untouched rather than getting a clipped mark.
- `zeroSizedCanvasIsANoOp` — guards the degenerate path.
- `exportOverlayRendersAtTheRequestedSize` / `exportOverlayIsNilForAnEmptyFrame`.

### Unit — `Tests/Unit/ReelExportTests.swift` (2 NEW cases, 3 existing)
- `everyExportCarriesTheWatermarkEvenWithNoCaption` — **the load-bearing test.**
  Exports with no caption/speed/mute, then decodes a real frame back out of the
  written .mp4 and asserts the corner carries the mark. Asserts twice: the
  translucent plate shifts the corner off the flat background, and near-white
  pixels exist there (a saturated source hue never contains white). Written this
  way so it fails if the composition is ever made conditional again.
- `watermarkAndCaptionCoexist` — burning one in doesn't drop the other.

### UITest — `Tests/UITests/ReleasedUITests.swift` (1 NEW case)
- `testEveryAngleTileIsWatermarked` — runs off `-MOCK_RELEASED` fixtures (no
  Firebase), asserts a mark on each angle tile and that it does not intersect the
  play button.

## Results — full suite, iPhone 17 Pro

| Suite | Result |
|---|---|
| `MobileCommanderTests` (unit, 75 tests / 10 suites) | **75/75 pass** |
| `ReleasedUITests` | **3/3 pass** |
| `VideosUITests` | **7/7 pass** |
| `ChatUITests`, `SignInUITests` | 6 fail — **environmental, see below** |

The Chat and SignIn UITests run against the Firebase Local Emulator Suite and the
`firebase` CLI is not installed on this machine (CLAUDE.md documents this; the app
can't reach Auth/Firestore, so they never reach a signed-in UI). They are
unrelated to this change and fail the same way without it.

### A note on simulator contention
Early runs showed the app crashing on teardown, `angle-play` reporting
`hittable=false`, and a window frame of 134×291 (⅓ scale). None of it was real: a
concurrent worker on this machine had a different app ("Simple Strength")
foregrounded on the shared simulator, so measurements were taken against an app
that wasn't on screen. Re-run on a dedicated device (`xcrun simctl create`),
everything is green and all play buttons are `hittable=true`. If these suites look
broken, check for other booted simulators before believing it.

## Visual verification (`output/`)
- `released-watermarked.png` — the reported screen, mark on all six angle tiles.
- `export-watermark-burnin.png` — the burn-in at 1080×1920.
- `exported-frame-watermarked.png` — a frame decoded back out of an exported .mp4.

## How to Run
```bash
# Unit only (hermetic, fast):
SKIP_EMULATOR=1 scripts/run-tests.sh

# The watermark tests specifically:
xcodebuild test -scheme MobileCommander \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:MobileCommanderTests/WatermarkTests \
  -only-testing:MobileCommanderTests/ReelExportTests

# The Released tab UITest (no emulator needed — mock seam):
xcodebuild test -scheme MobileCommander \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:MobileCommanderUITests/ReleasedUITests
```
