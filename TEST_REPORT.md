# Test report — #1071 Released-tab poster thumbnails

Run on 2026-07-19 against `task/1071-ios-load-the-poster-thumbnail-in-the-rel`.

## How to run

```sh
xcodegen generate                     # required: PosterImage.swift is a NEW file
SKIP_EMULATOR=1 scripts/run-tests.sh  # unit tests (hermetic)

# UITests, no Firebase emulator needed (-MOCK_RELEASED fixtures)
xcodebuild test -scheme MobileCommander \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:MobileCommanderUITests/ReleasedUITests
```

## Status

| Suite | Destination | Result |
|---|---|---|
| Unit (Swift Testing, 96 tests / 11 suites) | iPhone 17 Pro | **pass** (exit 0) |
| `ReleasedUITests` — poster + geometry + watermark | iPhone 17 Pro | **pass** (exit 0) |
| `ReleasedUITests/testAnglesShowPosterThumbnails`, `testReleasedShowsCards` | iPad Air 11-inch (M4) | **pass** (exit 0) |

## Tests added

**Unit — `Tests/Unit/ReleasedRecordingTests.swift`**
- `parsesPerAnglePosterURL` — `videos[].thumbnail_url` (including a real
  percent-encoded Firebase download URL with a token) survives the parse.
- `angleWithNoPosterYetStillParses` — a class released before the watcher's next
  pass parses fine with `thumbnailURL == nil`; the angle is not dropped.
- `emptyPosterURLBecomesNil` — a failed extraction that writes `""` reads as "no
  poster" rather than being handed to the loader as a URL.

**UITest — `Tests/UITests/ReleasedUITests.swift`**
- `testAnglesShowPosterThumbnails` — asserts a poster actually paints on each
  angle tile, and that it stays inside its tile's frame. That second assertion is
  the iPad regression guard: a landscape poster with `scaledToFill` and no
  `.clipped()` inflates the layout + hit frame and swallows the neighbouring
  angle's taps (the bug previously fixed in the Videos grid). It runs off a
  bundled `file://` fixture, so it needs no network or Firestore.

## Manual verification

- Screenshots of the Released tab with posters rendering, built from a dedicated
  `-derivedDataPath` to avoid installing a stale binary:
  `output/released-posters-iphone.png`, `output/released-posters-ipad.png`.
  Both show posters filling the tiles with the play glyph and Palmr mark on top,
  and the poster-less WebM fixture card still falling back to a black tile —
  so both branches are covered.
- All 9 live `released_recordings` poster URLs fetch **HTTP 200 `image/jpeg`**
  (24–35 KB each), confirming the URL shape the app loads is real and reachable.

## Known flake (pre-existing, not from this change)

`xcodebuild test` on the full `ReleasedUITests` suite intermittently exits 65 with
`Restarting after unexpected exit, crash, or test timeout`. The runner dies during
`Setting up automation session`, before the app renders; no app crash report is
produced. **Verified pre-existing**: stashing this branch's changes and running
the same suite on the baseline produced the same exit 65 with *three* restarts
(this branch's run had two). Individual tests pass on re-run. Worth chasing
separately — it makes the suite's exit code untrustworthy.
