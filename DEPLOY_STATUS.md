# Deploy status — #1071

**Target:** TestFlight (`ai.palmr.emma`, App Store Connect app id 6780673334).

**Deployed this run:** nothing. Per the task ("will be batched to a TestFlight
build after review") this change is left unshipped for the batch.

**Build status:** `xcodebuild build -scheme MobileCommander` succeeds for the
iPhone 17 Pro simulator (exit 0). Unit + Released UITests pass on iPhone 17 Pro
and iPad Air 11-inch (M4) — see TEST_REPORT.md.

**Not done (deliberately):** no `CURRENT_PROJECT_VERSION` bump and no
`scripts/upload-testflight.sh` run. `project.yml` is still at `20260719.1`, which
was already uploaded in commit 4cc3cb2 — **whoever cuts the next build must bump
it first**, or the upload is rejected as a duplicate build number.

## Server side (a different repo — nothing to deploy from here)

The poster pipeline lives in `/Users/jc/repos/experimental/commander`, not in this
iOS repo, so there is no deploy artifact here for it. What changed operationally:

- Ran `worker/generate-recording-posters.mjs` in the foreground to backfill the
  two `released_recordings` docs released on 2026-07-17 that had no poster.
  All 3 docs / 9 angles now carry `videos[].thumbnail_url`; every URL returns
  HTTP 200 `image/jpeg`. This is a data backfill, not a code change.
- `com.palmr.recording-posters` had stopped firing (its log had not been written
  since 2026-07-17 22:36). `launchctl kickstart -k` runs it correctly, but it is
  still not self-scheduling — see FOLLOW_UP.md, this needs a human at the machine.
