# Test report — #1069

## How to run

```sh
SKIP_EMULATOR=1 scripts/run-tests.sh    # unit only (hermetic, fast)
scripts/run-tests.sh                    # unit + UITests (needs `firebase` on PATH)

# Mock-seam UITests, no emulator needed:
xcodebuild test -scheme MobileCommander \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:MobileCommanderUITests/VideosUITests
```

## Status

### Unit — PASS (95/95)

Includes two new cases in `Tests/Unit/VideoTests.swift`:

- `permissionDeniedGetsActionableMessage` — a Firestore `permission-denied` no
  longer surfaces the raw "Missing or insufficient permissions."
- `nonPermissionErrorsKeepTheirOwnMessage` — other failures keep Firestore's own
  wording.

### UITest — new test PASSES

`VideosUITests.testLoadFailureOffersRetryAndRecovers` (new) passes. It launches
with `-MOCK_VIDEOS -MOCK_VIDEOS_ERROR "Missing or insufficient permissions."`,
asserts the error state appears with a Try Again button, taps it, and asserts the
grid loads and the error clears. Reproduces #1069's screen offline — no Firestore
or Storage needed.

Also passing in the same suite: `testGridShowsReels`,
`testGridCellsDoNotOverlapAndAreHittable`, `testTappingEachReelOpensThatReel`,
`testReportIssueSheetOpens`.

### Rules — PASS (10/10)

Run against the *deployed* ruleset via the Firebase Rules test API:

- authed read + **list** of `commander_videos` → ALLOW (the Videos tab query)
- authed read of `released_recordings`, `commander_channels`,
  `commander_presence` → ALLOW
- anonymous read of `commander_videos`, `released_recordings` → DENY
- `coach_users` owner, `coach_clients`, `pt_patients` → ALLOW (regression check
  that the other app on this project still works)

## Known flakiness — PRE-EXISTING, not caused by this change

`testOpenCloseThenOpenAnother`, `testShareReelToChatOpensSheet`, and
`testUnsupportedFormatReelShowsMessage` intermittently die with "Restarting after
unexpected exit, crash, or test timeout" (`xcodebuild` exit 65). All three drive
the full-screen AVPlayer feed.

Verified pre-existing: I stashed every change and ran the same three tests on the
clean baseline — identical failure and exit code, with a *different* one of the
three surviving each run. The crash order is nondeterministic, which is the
signature of simulator/AVPlayer instability rather than a code fault. Each of the
three passes when run alone.

## Gotcha worth fixing separately

`scripts/run-tests.sh` exited **0** on a hard Swift compile failure — it reported
"Testing failed / ** TEST FAILED **" in its output but still returned success.
That is the masked-failure trap CLAUDE.md warns about, and here it is in the test
script itself. Do not trust that script's exit code; grep its output.
