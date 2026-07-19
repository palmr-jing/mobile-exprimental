# Test report — #1075 (watermark survives the viewer and the saved file)

## Status: passing

Final run: **99 unit tests in 12 suites + 16 UI test cases, 0 failures, 0 skips.**

## How to run

The default `scripts/run-tests.sh` shares the booted simulator and DerivedData with
other workers on this machine, which produced three separate false failures during
this task (see "Contention" below). Run isolated:

```sh
xcodegen generate

# Isolated simulator + DerivedData — the reliable invocation.
UDID=$(xcrun simctl create task-sim "iPhone 17 Pro"); xcrun simctl boot "$UDID"
xcodebuild test -scheme MobileCommander \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath /tmp/dd-mc \
  -only-testing:MobileCommanderTests \
  -only-testing:MobileCommanderUITests/ReleasedUITests \
  -only-testing:MobileCommanderUITests/VideosUITests
xcrun simctl delete "$UDID"
```

`SKIP_EMULATOR=1 scripts/run-tests.sh` also works for unit tests only, but will
report a spurious `** TEST FAILED **` if another worker is building concurrently.

## What was added

### `Tests/Unit/VideoWatermarkTests.swift` (new, 6 tests)
Pixel-level tests of the burn-in — the guarantee the fix rests on. Each decodes a
real frame out of a real re-encoded file rather than asserting the composition was
configured, because the bug was precisely that the watermark existed everywhere
except in the bytes.

| Test | Asserts |
|---|---|
| `burnsTheMarkIntoTheSavedFilesPixels` | White mark present in the bottom-right of a decoded frame; rest of frame untouched |
| `brandsTheWholeRecordingNotJustTheOpeningFrames` | Mark present at 0.5s, 2.5s and 4.5s — a burn-in covering only the opening would otherwise pass a single-frame check |
| `keepsTheFullRecordingNotJustASegment` | Duration preserved (no accidental trim) |
| `carriesTheClassAudioAcross` | Audio track survives the re-encode; guards the fixture itself so a silent source can't make it vacuous |
| `namesTheOutputMp4BecauseItAlwaysReencodesToMp4` | `.mov` → `.mp4`, empty → `video.mp4` |
| `aFileWithNoVideoTrackFailsInsteadOfWritingSomethingUnbranded` | Throws rather than silently emitting an unbranded file |

### `Tests/UITests/ReleasedUITests.swift` — `testOpenedViewerKeepsTheWatermark` (new)
Opens an angle full-size and asserts the Palmr mark is present and positioned
bottom-trailing on the player. Attaches a screenshot
(`output/angle-viewer-watermarked.png`) as visual evidence.

This test initially **skipped**, because the `-MOCK_RELEASED` fixtures pointed at
`gtv-videos-bucket` sample URLs that now answer 403 — so the viewer resolved to the
"can't play" guard and there was no video surface to brand. A skip was reported
rather than a pass so it could not go green on untested code. It was then made to
run for real by bundling a 17KB clip (`Resources/test-sample-clip.mp4`, generated
with ffmpeg) and pointing the first mock angle at it. This also removes the
long-standing gap noted in `ReleasedRecordingsView.mock` that playback was not
verifiable offline.

### `Tests/Unit/VideoFixtures.swift` (new)
Video fixture helpers extracted from `ReelExportTests` (they were `private static`)
so both suites share one copy: `makeSampleVideo`, `probeFrame`, and
`makeSampleVideoWithAudio`.

Note: the first version of `makeSampleVideoWithAudio` hand-rolled `CMSampleBuffer`s
into an `AVAssetWriter` and **crashed the test host process**. It was rewritten on
`AVAudioFile` + a composition merge. A fixture that can take down the process is
worse than no fixture.

## Existing tests
`ReelExportTests` and `WatermarkTests` still pass unchanged in behaviour.
`WatermarkTests` was updated only where `ReelExport.makeOverlay` moved to
`VideoWatermark.makeOverlay`.

## Contention (important)

Three test runs went red during this task for reasons unrelated to the code:

1. `Early unexpected exit ... Test crashed with signal kill` — two other workers
   (`task-1071`, `task-1072`) were running `xcodebuild test` against the same booted
   `iPhone 17 Pro`.
2. `Failed to create a bundle instance ... Check that the bundle exists on disk` —
   another worker rebuilt into the shared DerivedData mid-run, replacing the
   `.xctest` bundle.
3. UITest log lines from another worker bled into a `SKIP_EMULATOR=1` unit run.

Only one failure in this task was real (the fixture crash above). Before believing a
red run here, check `xcrun simctl list devices booted` and `pgrep -fl xcodebuild`.
