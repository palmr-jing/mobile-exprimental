# Test report — Task #1064 (tap a Released thumbnail to open + download)

Run 2026-07-18/19 from `.worktrees/task-1064`, iOS 26.4 simulators.

## Suites

| Suite | Covers | Run it |
| --- | --- | --- |
| `MobileCommanderTests` (Swift Testing, 80 tests) | Pure logic. New: `VideoDownloadTests` (14 cases) — container detection, Photos compatibility, saved-filename derivation. | `SKIP_EMULATOR=1 scripts/run-tests.sh` |
| `MobileCommanderUITests/ReleasedUITests` (5 tests) | Released tab from `-MOCK_RELEASED` fixtures: cards, share sheet, and the new open-viewer / re-open / unsupported-format flows. No Firebase, no network. | `xcodebuild test -scheme MobileCommander -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:MobileCommanderUITests/ReleasedUITests` |
| `MobileCommanderUITests/VideosUITests` (7 tests) | Videos tab regression check. | same, `-only-testing:MobileCommanderUITests/VideosUITests` |

## Status: passing

- Unit: **80/80 passed** (3.9s).
- `ReleasedUITests`: **5/5 passed** on iPhone 17e **and** iPad Air 11-inch (M4).
- `VideosUITests`: **7/7 passed** — no regression from the Released changes.

New UITests:

- `testTappingThumbnailOpensViewerWithDownload` — tap a thumbnail → viewer opens with a
  player and an enabled "Save to Photos"; Done returns to the cards.
- `testViewerCanBeReopenedAfterDismiss` — open/close twice, guarding the stuck-modal
  failure that once left the Videos grid dead to taps on iPad.
- `testUnsupportedFormatDownloadShowsMessage` — a WebM release shows the "ask for an MP4"
  message instead of downloading a file Photos can't store. Runs offline: the format
  guard fires before any network call or permission prompt.

## Manual end-to-end check (not committed — needs network + a Photos grant)

The committed tests stop short of a real download on purpose. That path was verified by
hand on 2026-07-18 with a temporary test pointing a fixture at a live MP4:

- Permission prompt appeared with the expected copy: *"Emma" would like to add to your Photos*.
- The button progressed idle → "Saving to Photos…" → "Saved to Photos".
- Asset confirmed on disk in the simulator's library:
  `.../Devices/<id>/data/Media/DCIM/100APPLE/IMG_0007.MP4`, 991,017 bytes, matching the source file.

The temporary test and the fixture edit were both reverted; the working tree has neither.

## Notes for the next run

- The `-MOCK_RELEASED` fixture URLs (`commondatastorage.googleapis.com/gtv-videos-bucket`)
  now answer **403**, so mock tiles open to a black player. No committed test depends on
  playback, but a manual smoke test of playback needs a live release or a fresh sample URL.
- Another worktree (`task-1067`) drove the **same** `iPhone 17 Pro` simulator concurrently,
  producing a bogus `VideosUITests/testReportIssueSheetOpens` failure and cross-contaminated
  `/tmp` logs. Re-running on a dedicated device (`-destination 'name=iPhone 17e'
  -derivedDataPath /tmp/dd-1064`) was green. When worker runs overlap, pin a distinct
  simulator and derived-data path.
- The `Could not reach Cloud Firestore backend` lines during the unit run are expected —
  unit tests are hermetic.
