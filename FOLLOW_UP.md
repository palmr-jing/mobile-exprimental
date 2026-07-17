# Follow-up — Task #1049: [iOS] Reel 30 clips doesn't play when clicked on

**What was done**: Diagnosed why the "Reel · 30 clips" card opened to a black
frame that never played, and fixed the iOS side so it now shows a clear message
instead of hanging silently. The reel is unplayable because of its file format
(see root cause); iOS can't decode it natively, so the durable fix is producer-
side and is spelled out under "Action items".

## Root cause

"Reel · N clips" cards are the only reels built in the browser. In
`everbot-manage`, `ReelEditor.jsx` → `composeUploadAndRelease()` composes the
clips with `MediaRecorder` (`components/composeReel.js`) and uploads the result.
The container is chosen by `pickRecorderMime()` in `components/watermark.js`,
which prefers `video/mp4;codecs=h264` but **falls back to `video/webm`** when the
browser can't encode H.264 — which is exactly what Chrome does. So the uploaded
file is `wallcam/reels/<id>.webm`, and its `commander_videos.video_url` points at
that WebM.

iOS `AVPlayer`/AVFoundation has no WebM/VP9 decoder, so the tapped reel loaded a
URL it could never render. The single-source "fighter reels" (e.g. Muay Thai)
play fine because the Python pipeline renders those as H.264 MP4 — only the
browser-composed multi-clip reels are affected.

Second problem, iOS-only: `ReelPlayerView` never observed playback failure. It
set `failed` only when there was no URL at all, so an undecodable-but-present URL
sat on a black frame forever with no feedback. That's the part fixed here.

## What was changed (iOS)

- `ReelPlayerView` now (a) rejects known-undecodable containers by extension up
  front with a clear message, (b) probes `AVURLAsset.isPlayable` before wiring the
  player so any other undecodable asset also surfaces an error, and (c) observes
  `AVPlayerItemFailedToPlayToEndTime` to catch a mid-stream failure. Any of these
  shows "This reel isn't in a format iOS can play yet." (or the underlying error)
  instead of a black screen.
- `AssignedVideo.isLikelyUnsupportedFormat` — pure, unit-tested helper that reads
  the file extension from the video URL or storage path (works past a Firebase
  download URL's percent-encoded path + query string).

This makes the app honest and unstuck. It does **not** make the WebM reel play —
nothing on the iOS side can, without bundling a third-party VP9 decoder, which is
not worth it.

## What needs review

- Confirm the message copy ("This reel isn't in a format iOS can play yet.") is
  acceptable, or swap it for whatever product wants users to see.
- Decide the durable fix direction (below): force MP4 at compose time vs. a
  server-side transcode. That choice lives in the `everbot-manage` repo, not here.
- Sanity-check the extension list in `AssignedVideo.unsupportedVideoExtensions`
  (`webm`, `mkv`, `ogv`, `ogg`) against what the pipeline can emit.

## Action items (the real fix lives in another repo)

1. **`everbot-manage` — make composed reels playable on iOS.** Two options:
   - Preferred: transcode the composed upload to H.264 MP4 server-side (a Storage-
     triggered Cloud Function running ffmpeg) and write that MP4's URL into
     `commander_videos.video_url`. This is the only option that works regardless of
     which browser the admin used.
   - Cheaper but partial: only allow "Release to app" when `pickRecorderMime()`
     returned an MP4 mime (block/warn on WebM), so no unplayable reel is ever
     released. Doesn't help admins on Chrome.
   - Files: `components/watermark.js` (`pickRecorderMime`),
     `components/ReelEditor.jsx` (`composeUploadAndRelease`).
2. **Backfill** any WebM docs already in `commander_videos` once the transcode
   exists (re-release, or a one-off transcode job), so previously-released reels
   like this one become playable.
3. Push this branch to remote (the worker does this automatically).

## Files changed

- `Sources/Views/Videos/ReelPlayerView.swift` — probe playability + observe
  playback failure; show a message instead of a permanent black frame.
- `Sources/Models/AssignedVideo.swift` — add `isLikelyUnsupportedFormat` +
  `unsupportedVideoExtensions`.
- `Sources/Views/Videos/VideosView.swift` — add a WebM "Reel · 30 clips" mock so
  the bug is reproducible offline in the UITest seam.
- `Tests/Unit/VideoTests.swift` — 2 tests for `isLikelyUnsupportedFormat`.
- `Tests/UITests/VideosUITests.swift` — `testUnsupportedFormatReelShowsMessage`:
  tap the WebM reel, assert the failure message, close, return to grid.
