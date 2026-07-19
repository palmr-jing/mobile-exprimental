# Follow-up — #1072, Palmr logo + wordmark on Released videos

## What was done

Replaced the app's hand-drawn watermark with manage.everbot.org's actual mark —
a byte-identical copy of its `palmr-watermark.png` LogoPair asset — and put it on
the Released full-size viewer, which had no branding at all before.

## The thing worth knowing before reviewing

The #1067 watermark was **not** manage's mark. It drew a leaf glyph plus the word
"PALMR" in a semibold system font on a translucent black pill. manage and the
`video-pipe` reel pipeline both stamp a single combined raster — leaf and the
"Palmr" wordmark baked into one warm-white (`#F1EDE3`) PNG, bottom-right, fully
opaque, on **no background plate**. Different glyph spacing, different casing,
different colour, plus a plate that shouldn't be there.

Since burned-in pipeline reels and app-side overlays get seen next to each other,
I matched the real thing rather than tuning the re-creation: the asset is now
copied verbatim from `everbot-manage/public/palmr-watermark.png` (verified
identical by sha1), and the geometry is a port of manage's `components/watermark.js`
— width 14% of the frame clamped to [96, 240], margin 2% clamped to [12, 32].

**The plate is gone on purpose.** That is what manage stamps. The tradeoff is
real and you should look at it: warm white with no plate and no shadow has less
contrast against a bright frame than the old pill did. `drawsNoBackgroundPlateBehindTheMark`
locks this in, so if you decide legibility beats fidelity, that test is the thing
to change and this is a deliberate decision to revisit, not an oversight.

## What needs review

- **Look at `output/released-tab-watermark.png`.** On a ~107pt angle tile the
  mark sits at its 56pt legibility floor, so it spans about half the tile width
  and passes close under the centred play glyph. It reads fine and doesn't cover
  the control, but it is snug — this is the direct consequence of asking for the
  wordmark on a tile a third of a card wide. Lowering `PalmrWatermark`'s floor
  from 56 is the one-line dial if you want it smaller.
- **Confirm the no-plate call** against a real bright class recording, not the
  flat blue test fixture. The mock fixture can't tell you how the warm white
  reads over a sunlit gym floor.
- **`AngleViewerView.teardown()` now deactivates the audio session.** That's a
  real behaviour change beyond the watermark: closing the viewer no longer leaves
  the user's music ducked. It was needed because making the fixtures play
  exposed a leak that hung the app on relaunch mid-suite (details in
  `TEST_REPORT.md`). Worth a sanity check that playing an angle, closing it, then
  reopening still works with music playing in the background.
- **`Resources/test-angle.mp4` ships in the app bundle** — 2.9 KB, only
  referenced from the `-MOCK_RELEASED` seam, so it's inert in production but it
  does travel in the binary. Say so if you'd rather it didn't.
- The reel player's watermark moved to the shared modifier, so **the Videos tab
  mark changed appearance too**. That wasn't in the ask but leaving two different
  Palmr marks in one app seemed worse. Flag it if you disagree.

## Action items

- Bump `CURRENT_PROJECT_VERSION` in `project.yml` when this gets batched into a
  TestFlight build — it is still `20260719.1` and was deliberately not bumped.
- Push the branch (the worker does this automatically).
- Decide the plate question above before the build goes to testers.
- Longer term, and outside this task: the app can only brand its own playback
  surface. Released class recordings are streamed unmodified from Storage, so a
  video saved to Photos or shared out of the app carries no mark. If Released
  recordings need to be watermarked in-pixel like reels are, that belongs in the
  release pipeline on manage's side.

## Files changed

- `Resources/Assets.xcassets/PalmrLogoPair.imageset/` — **new.** manage's
  `palmr-watermark.png` (3115×624 RGBA), copied verbatim.
- `Resources/test-angle.mp4` — **new.** 3-second H.264 clip so `-MOCK_RELEASED`
  can reach a real player with no network.
- `Sources/Design/Watermark.swift` — rewritten around the LogoPair asset.
  Dropped the `Style` enum (compact/regular) since every surface now shows logo
  and wordmark; added `burnInRect` and `width(forSurfaceWidth:)` as testable
  geometry; the overlay reads its surface size from a `GeometryReader` so one
  call site works on a tile and on an iPad player. Asset lookup falls back to the
  code's own bundle so host-less unit tests resolve it.
- `Sources/Views/Recordings/AngleViewerView.swift` — watermark on the full-size
  player (the reported gap), shown only once playback starts; audio session
  released in `teardown()`.
- `Sources/Views/Recordings/ReleasedRecordingsView.swift` — angle tiles show the
  full mark instead of the mark-only badge; first mock angle points at the
  bundled clip.
- `Sources/Views/Videos/ReelPlayerView.swift` — uses the shared `palmrWatermark`
  modifier instead of its own copy of the overlay.
- `Tests/Unit/WatermarkTests.swift` — rewritten against manage's spec; added a
  `fractionMatching` probe helper.
- `Tests/UITests/ReleasedUITests.swift` — added `testFullSizeViewerIsWatermarked`.
- `MobileCommander.xcodeproj` — regenerated (build artifact).
- `TEST_REPORT.md`, `DEPLOY_STATUS.md` — new.
