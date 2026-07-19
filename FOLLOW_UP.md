# Follow-up — #1071 Released-tab poster thumbnails

**What was done**: The Released grid now paints a cached poster frame per camera
angle instead of a black tile, matching how manage.everbot.org/recordings loads.
The server-side field it reads already existed but had gone stale, so I also
backfilled the missing posters in `released_recordings`.

## What was actually wrong (the task's premise was half right)

The task said released docs have no thumbnail field and asked whether the
`com.palmr.recording-posters` watcher should populate it. It already does — the
watcher (in `/Users/jc/repos/experimental/commander`, a different repo) extracts
a first-frame JPEG per angle with ffmpeg and writes `videos[].thumbnail_url`.
The real problem was that **it had stopped running on 2026-07-17 22:36**, so the
two classes released that day had no poster. So there were two gaps, not one:
stale data, and an iOS grid that used plain `AsyncImage`.

Both are addressed. All 3 docs / 9 angles now carry a poster, and every one of
those URLs returns HTTP 200 `image/jpeg`.

## What needs review

- **The recycling fix in `PosterImage`** is the subtle part. SwiftUI keeps
  `@State` when a `LazyVStack` recycles a row, so an "already loaded, skip"
  guard would leave the *previous* angle's frame on a recycled tile forever. The
  `.task(id: url)` deliberately does not early-out on a non-nil image, and drops
  the stale image before loading. Worth a second pair of eyes — my first version
  had exactly that bug and the UITests did not catch it (the fixture list is too
  short to force a recycle). A longer fixture list would be a good addition.
- **`nonisolated(unsafe)` on `PosterCache.memory`.** Deliberate: it lets the view
  read the cache synchronously in `init` so a recycled tile paints in its first
  frame, which is the whole speed win. It's sound because `NSCache` does its own
  locking, but it is an unsafe opt-out and should be a conscious call, not a
  rubber stamp.
- **Verify the poster is the frame you'd expect.** The generator seeks to
  `-ss 1`. For a class recording that starts on a dark or empty room, the poster
  may be a near-black frame that looks like the old bug. Check
  `output/released-posters-*.png` shows what you want testers to see.
- The `angle-poster` accessibility element is new. Confirm it does not disrupt
  VoiceOver on the tile (the poster sits inside the `angle-play` button).

## Action items

1. **A human at that Mac needs to fix the watcher's scheduling.** This is the one
   thing I could not resolve, and it matters: without it, every future "Release
   to app" ships black tiles again in ~10 minutes' worth of releases.
   `launchctl kickstart -k gui/$(id -u)/com.palmr.recording-posters` runs it
   correctly, but it will not fire on its own. I booted it out and bootstrapped
   it cleanly; 12 minutes later `launchctl print` still showed `runs = 0` with an
   untouched log, despite `StartInterval 600` and `RunAtLoad true`. The plist is
   correct, so this is macOS holding the agent back — check **System Settings →
   General → Login Items & Extensions** for a disabled entry, and confirm it is
   running in a real GUI login session.
2. **Bump `CURRENT_PROJECT_VERSION` in `project.yml` before the next TestFlight
   upload.** It is still `20260719.1`, which was already uploaded (commit
   4cc3cb2); re-uploading it is rejected.
3. Consider having the watcher run on a `released_recordings` write trigger
   rather than a 10-minute poll, so a newly released class gets posters
   immediately instead of showing black tiles until the next pass.
4. Optional: `PosterImage` is generic and the Videos grid still uses raw
   `AsyncImage` with its own `file://` special-case. Swapping it over would give
   that grid the same caching. Left alone to keep this change scoped.

## Known issue, not caused by this change

`ReleasedUITests` as a whole suite intermittently exits 65 with
`Restarting after unexpected exit, crash, or test timeout`. I confirmed this is
pre-existing by stashing the branch and re-running: baseline showed the same
failure with three restarts vs. two here. Individual tests pass. Details in
TEST_REPORT.md.

## Files changed

- `Sources/Views/Shared/PosterImage.swift` — **new.** Cached poster loader:
  in-memory decoded-image cache read synchronously at init (no black flash on
  scroll recycle), a private disk-backed `URLCache` so posters survive a cold
  launch, request de-duplication, off-main decoding, and `file://` support that
  `AsyncImage` lacks.
- `Sources/Views/Recordings/ReleasedRecordingsView.swift` — angle tiles use
  `PosterImage` instead of `AsyncImage`; mock fixtures carry a bundled poster so
  the path is testable offline.
- `Sources/Models/ReleasedRecording.swift` — an empty `thumbnail_url` now parses
  as nil rather than being passed along; comment corrected to say the watcher
  does write this field.
- `Tests/Unit/ReleasedRecordingTests.swift` — 3 tests for poster parsing.
- `Tests/UITests/ReleasedUITests.swift` — `testAnglesShowPosterThumbnails`,
  including the iPad poster-overflow guard.
- `MobileCommander.xcodeproj/project.pbxproj` — regenerated by `xcodegen` to pick
  up the new file.
- `TEST_REPORT.md`, `DEPLOY_STATUS.md`, `output/released-posters-*.png` — results
  and visual proof.
