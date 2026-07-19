# Follow-up — Task #1063 ([iOS] Click on videos in app and they don't load or come up)

## What was done
The Released tab's angle tiles handed their URL straight to `AVPlayer` with no playability check and
no failure observer, so any angle that couldn't decode — or whose Storage token had expired — sat on
a black frame forever with nothing on screen to explain it. I ported the failure handling the *reel*
player already got in #1049 (probe → observe → say why) onto the angle tile, so every tap now ends in
either a playing video or a readable message.

## Read this first — the honest limitation
**This does not make the user's videos play. It makes the app tell them why one didn't.**

I could not reach the user's live data (Firestore/Storage need an interactive Google sign-in this run
can't do), so I could not confirm *which* failure their screenshot shows. There are two candidates and
they need different fixes:

1. **The angle has no `download_url` at all.** Their screenshot supports this — the first two cards
   have tiles with no play button, which is exactly the old no-URL rendering. If so the bug is
   **producer-side**: "Release to app" wrote a doc with missing/blank URLs. Nothing in the iOS app
   can fix that; those tiles will now read "Not available" instead of being blank rectangles.
2. **The URL exists but won't play** — a WebM/VP9 file iOS has no decoder for, or an expired/403
   tokenized Storage URL. Those tiles will now read "Format not supported on iOS" / "Couldn't load
   this angle".

Either way the next step is the same: **install this build, tap a failing tile, and read the message.**
That message identifies which of the two it is. That's the diagnostic this change buys.

## What needs review
- Install on a device and tap the angles that were black in the report screenshot. Note the exact
  message — it tells you whether this is a producer-side data bug or a format/token bug.
- If tiles say **"Not available"**: check `released_recordings` in Firestore for those docs. The
  `videos[]` entries are missing `download_url`. Fix belongs in everbot-manage's "Release to app".
- If tiles say **"Format not supported on iOS"**: the release pipeline is emitting WebM. Same
  producer-side root cause flagged in #1049 — the durable fix is emitting/transcoding H.264 MP4.
- Confirm the failure text is legible on a real device. The tiles are ~1/3 screen width and the
  message renders at 9pt with `minimumScaleFactor(0.8)`; it read fine in the simulator screenshot
  (`output/released-failure-states-after.png`) but is worth a real-eyes check.
- The `isPlayable` probe adds a round trip between tap and playback. On a good network it's
  imperceptible and a spinner covers it, but check it doesn't feel sluggish on cellular.

## Action items
- Push this branch (the worker does this automatically) and open the PR.
- **Bump `CURRENT_PROJECT_VERSION` in `project.yml`** before any TestFlight upload — it's still
  `20260717.1` from #1049, and a repeat build number is rejected.
- **I did not upload to TestFlight.** Local suites pass, so CLAUDE.md's gate is satisfied, but
  shipping burns a build number and wasn't part of the ask. Run
  `ASC_ISSUER_ID=<uuid> scripts/upload-testflight.sh` when you want it out.
- File the producer-side ticket in everbot-manage once the on-device message tells you which root
  cause it is.

## Files changed
- `Sources/Views/Recordings/ReleasedRecordingsView.swift` — `AnglePlayer` now rejects known-undecodable
  containers by extension, probes `AVURLAsset.isPlayable` before wiring the player, observes
  `AVPlayerItemFailedToPlayToEndTime` for mid-stream failures, and renders a message + spinner state
  instead of a black tile. Source-less angles say "Not available" in words rather than showing a bare
  glyph. Added `teardown()` on disappear so a scrolled-off tile stops playing and drops its observer.
  Also added a mock card (WebM angle + source-less angle) that reproduces the bug offline.
- `Sources/Models/ReleasedRecording.swift` — added `Angle.isLikelyUnsupportedFormat`, reusing the
  shared `AssignedVideo.unsupportedVideoExtensions` list rather than duplicating it.
- `Tests/Unit/ReleasedRecordingTests.swift` — 5 cases for the detector (Firebase URL encoding,
  `storage_path` fallback, no-source case).
- `Tests/UITests/ReleasedUITests.swift` — 2 cases: tapping an undecodable angle shows a message;
  a source-less angle shows "Not available". Plus a bounded `scrollIntoView` helper (the obvious
  `while !isHittable { swipeUp() }` hangs the suite forever if the element never becomes hittable).
- `TEST_REPORT.md`, `DEPLOY_STATUS.md` — results and the concurrent-worktree gotcha.
- `output/` — the reported screenshot and the after-fix simulator capture.

## One environment note worth keeping
Another worktree (`task-1064`) was running `xcodebuild` against the same simulator and the same
DerivedData during this run. It produced convincing-looking failures in *my* tests — app crashes,
"Lost connection to the application", and a log listing test names from the other branch. If tests
fail strangely while other workers are active, re-run against a dedicated device and
`-derivedDataPath` before believing the failure. Details in TEST_REPORT.md.
