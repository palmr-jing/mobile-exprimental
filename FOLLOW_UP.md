# Follow-up — Task #1067: Palmr watermarks

**What was done**: Added the Palmr watermark to the app, in two places that were
both completely unbranded: it is now burned into the pixels of every reel the app
exports, and overlaid on the video surfaces the app displays (Released angle
tiles, full-screen reel player). `PalmrMark` already existed as an asset but was
only ever used as the Ask-Emma header logo.

## Read this first — the app can only watermark its own pixels

There are two kinds of video here, and only one can be fixed from this repo:

- **Reels the app exports** (reel editor → "Send to chat"). Rendered on-device, so
  the watermark is now burned into the file itself and travels with it anywhere.
  This was a real leak: before this change a plain trim exported with no branding
  at all, because the video composition was only built when a caption was set.
- **The released class recordings** (what the screenshot shows). These are
  rendered upstream by the release pipeline and only *streamed* here — the app
  never holds the file. The watermark on those tiles is a **display overlay**: it
  brands the app's playback surface, but it is not in the file. Download the
  `download_url` directly, or play the recording anywhere else, and there's no
  watermark.

So "nothing makes it to the app without a watermark" is now true for what the app
produces and for what the app *shows*. Making it true of the recording files
themselves needs a change where they're rendered (manage.everbot.org / the
commander repo), not here. That's the main call to make — see action items.

## What needs review

- **Placement and size.** Bottom-right. On the Released tiles it's the glyph only
  at ~25×19pt — those tiles are a third of a card wide and the wordmark wouldn't
  read. See `output/released-watermarked.png` and decide whether that's prominent
  enough or too subtle. Both are one-line changes in
  `Sources/Design/Watermark.swift` (`markHeight`, and the `0.055` unit in
  `drawBurnIn`).
- **Burn-in opacity** — plate black at 32%, contents white at 95%. See
  `output/export-watermark-burnin.png` (1080×1920) and
  `output/exported-frame-watermarked.png` (decoded back out of a real export).
- **Unplayable tiles get no mark.** A tile with no source URL ("Unavailable") is
  left alone — there's no content to brand. Say if you'd rather it appear anyway.
- **Export cost.** Every export now runs a Core Image composition pass where a
  caption-less trim used to pass through. Not noticeable on the test clips; worth
  checking on a long reel on an older device.

## Action items

- **Decide on pipeline-side watermarking for the released class recordings.** The
  app cannot do this, and it's the part of the original complaint that isn't fully
  addressed. If those need a burned-in watermark, file it against the repo that
  renders them.
- **Ship it**: bump `CURRENT_PROJECT_VERSION` in `project.yml`, `xcodegen
  generate`, then `ASC_ISSUER_ID=<uuid> scripts/upload-testflight.sh`. I did not
  bump or upload — that burns a build number and wasn't part of the ask.
- **Push the branch** (`task/1067-ios-also-where-are-the-palmr-watermarks`).
- **Unrelated, but worth knowing**: `ChatUITests` and `SignInUITests` (6 tests)
  fail on this machine because they need the Firebase emulator and the `firebase`
  CLI isn't installed. They fail identically without this change. `npm i -g
  firebase-tools` if you want them running.
- **Also unrelated**: something else on this machine was running a different app
  ("Simple Strength") on the shared iOS simulator during this run, which produced
  spurious crashes and false `hittable=false` readings until I moved to a
  dedicated device. Check for other booted simulators before trusting a red UITest
  run here.

## Files changed

- `Sources/Design/Watermark.swift` — NEW. One definition of the mark:
  `PalmrWatermark` (SwiftUI) for displayed video, a `.palmrWatermark()` modifier,
  and `drawBurnIn(canvasSize:)` (UIKit) for exported pixels. The white glyph is
  pre-rendered into its own canvas before compositing — tinting it in place would
  have repainted the plate underneath it.
- `Sources/Logic/ReelExport.swift` — the video composition is now always built, so
  no export path can skip the watermark. Caption drawing moved into the same
  canvas (one pass, not two). The overlay is built from the first frame's real
  extent and memoised behind a lock, since the filter handler runs concurrently.
- `Sources/Views/Recordings/ReleasedRecordingsView.swift` — watermark on each
  angle tile that has footage, via a `ViewModifier` rather than an `if` around the
  tile so view identity stays stable (an identity change there would tear down a
  playing `AVPlayer`).
- `Sources/Views/Videos/ReelPlayerView.swift` — watermark on the full-screen
  player, bottom-right with hit testing off so tap-to-pause still works through it.
- `Tests/Unit/WatermarkTests.swift` — NEW. Pixel assertions plus a reusable
  `Pixels` probe helper.
- `Tests/Unit/ReelExportTests.swift` — 2 new cases that decode a frame back out of
  an exported file.
- `Tests/UITests/ReleasedUITests.swift` — 1 new case.
- `TEST_REPORT.md`, `DEPLOY_STATUS.md` — rewritten for this task.
- `output/*.png` — visual evidence (force-added; `*.png` is gitignored).
