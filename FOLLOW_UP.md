# Follow-up — #1075 watermark missing in the viewer and in saved videos

## What was done

The report had two halves, and both were real: tapping a Released thumbnail opened a
full-size viewer that had no watermark on it, and "Save to Photos" downloaded the
released file and handed the raw bytes to Photos, so the saved video carried no
branding at all. Added the watermark overlay to the viewer's player, and made the
save path burn the mark into the video's pixels before it reaches the Photos library.

## The tradeoff you should decide on

**Saving a class recording is now much slower.** Burning a watermark into pixels
requires re-encoding, so saving a 45-minute class now costs roughly a playback's
worth of time and battery instead of a plain download. The button names the step
("Adding the Palmr watermark…") so it doesn't read as a hang, but it is a real
regression in save time and I could not make it free.

The alternative is branding the video **upstream**, in the release pipeline at
manage.everbot.org that renders these files — then the app downloads an
already-branded file and saving stays a plain copy. `Sources/Design/Watermark.swift`
already says that is where it belongs. If you own that pipeline, doing it there is
the better fix and this burn-in becomes a fallback. I did the app-side fix because
it is the half I could actually change and verify here.

Also: the burn-in **fails loudly** rather than falling back to saving the original.
A silent fallback would put an unbranded copy on someone's phone, which is the exact
bug being fixed. If you would rather the user get an unbranded video than an error,
that decision is one `catch` in `VideoDownload.saveToPhotos`.

## What needs review

- **Merge conflict risk with `task/1072`.** The worktree `.worktrees/task-1072` is on
  `task/1072-ios-released-videos-need-the-palmr-logo` — the same Released-tab
  watermark surface. Reconcile the two branches before either ships; they will
  likely collide in `ReleasedRecordingsView.swift` and `Watermark.swift`.
- **The viewer overlay does not follow into native fullscreen.** Tapping the
  expand control hands off to `AVPlayerViewController`, which draws its own surface,
  so the SwiftUI overlay is not on it. The saved file is still branded in its pixels.
  Decide whether fullscreen playback needs branding too.
- **Verify a real save on a device.** The burn-in is covered by pixel tests on
  generated clips, but no test exercises `saveToPhotos` end to end — that needs
  Photos authorization and a network. Save a real released class and confirm the mark
  is in the video in the Photos app, and check how long a full-length class takes.
- **Peak temp disk.** The download and the re-encoded copy briefly coexist. The
  original is deleted as soon as the burn-in succeeds, but a very long class still
  needs roughly 2× its size free at the crossover point.
- **The new bundled fixture ships in the app.** `Resources/test-sample-clip.mp4`
  (17KB) is in the app bundle and is only referenced under `TestConfig.isMockReleased`,
  so it is inert in production — but it is 17KB in every build. `Resources/` already
  contains `test-landscape.png` on the same basis.

## Action items

- Decide whether to move watermarking upstream into the release pipeline (above).
- Reconcile this branch with `task/1072` before shipping either.
- Bump `CURRENT_PROJECT_VERSION` in `project.yml` — it is still `20260719.1`, already
  used — then run the suite and upload. Not done here; see `DEPLOY_STATUS.md`.
- On a device: save a full-length released class and time it, then confirm the mark
  is in the saved video.

## Files changed

**Source**
- `Sources/Logic/VideoWatermark.swift` *(new)* — owns pixel-side watermarking:
  `burnIn(into:named:)` re-encodes a whole file with the mark, preserving audio and
  orientation; `videoComposition(for:text:pos:)` and `makeOverlay(...)` are the
  shared compositing, moved here from `ReelExport`.
- `Sources/Logic/ReelExport.swift` — delegates compositing to `VideoWatermark`
  instead of keeping its own copy; dropped the now-unused `UIKit`/`CoreImage`
  imports. Behaviour unchanged.
- `Sources/Logic/VideoDownload.swift` — `saveToPhotos` now burns in the watermark
  after downloading and before saving; added a `Phase` progress callback and a
  `watermark` failure case; deletes the unbranded original before saving the copy.
- `Sources/Views/Recordings/AngleViewerView.swift` — `.palmrWatermark()` on the
  player (the "when u look" half); `SaveState.saving` now carries a `Phase` so the
  button names the step.
- `Sources/Views/Recordings/ReleasedRecordingsView.swift` — the first mock angle now
  points at the bundled clip instead of a 403 URL, so the tap→play path is testable
  offline.
- `Resources/test-sample-clip.mp4` *(new)* — 17KB, 3s, 320x180, ffmpeg-generated.

**Tests**
- `Tests/Unit/VideoWatermarkTests.swift` *(new)* — 6 pixel-level tests of the burn-in.
- `Tests/Unit/VideoFixtures.swift` *(new)* — video fixture helpers shared by the
  export and watermark suites, extracted from `ReelExportTests`.
- `Tests/Unit/ReelExportTests.swift` — uses the shared fixtures; its private copies
  removed.
- `Tests/Unit/WatermarkTests.swift` — `ReelExport.makeOverlay` → `VideoWatermark.makeOverlay`.
- `Tests/UITests/ReleasedUITests.swift` — `testOpenedViewerKeepsTheWatermark`.

**Docs / evidence**
- `TEST_REPORT.md`, `DEPLOY_STATUS.md`, `FOLLOW_UP.md`.
- `output/angle-viewer-watermarked.png` — screenshot of the viewer with the mark.

## One caution on the test suite

Three runs went red during this task because other workers on this machine share the
booted simulator and DerivedData — including a run where the `.xctest` bundle was
replaced mid-test. Before believing a red run, check `xcrun simctl list devices booted`
and `pgrep -fl xcodebuild`. The isolated invocation is in `TEST_REPORT.md`.
