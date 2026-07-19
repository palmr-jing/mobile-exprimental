# Test report — task #1070 ([iOS] Can't load recordings)

## How to run

```sh
xcodegen generate                      # required: this branch adds 2 new Swift files

# Unit (Swift Testing) — hermetic, no emulator
SKIP_EMULATOR=1 scripts/run-tests.sh

# Released tab UITests — mock-seam driven, no Firebase/emulator needed.
# Use a DEDICATED simulator + per-task derived data (see caveat below).
UDID=$(xcrun simctl create wm-1070 "iPhone 17 Pro")
xcodebuild test -scheme MobileCommander \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath /tmp/dd-1070 \
  -only-testing:MobileCommanderUITests/ReleasedUITests
xcrun simctl delete "$UDID"
```

## Status: passing

### Unit — 101 tests / 13 suites, all passing

New this branch (`Tests/Unit/ListenerGateTests.swift`, 8 tests):

| Test | Pins |
| --- | --- |
| `attachesOnceForAHealthyIdentity` | repeat `.task` firings don't churn a live listener |
| `reattachesAfterAFailure` | **the #1070 regression** — a failed listener is not "live", so the next appearance re-attaches |
| `reattachesWhenIdentityChanges` | switching user moves the subscription |
| `neverAttachesWithoutAnIdentity` | no attach without auth (the rule is `request.auth != null`) |
| `reattachesAfterSignOutAndBackIn` | sign-out → sign-in re-attaches (previously the `started` flag survived) |
| `resetForcesAFreshAttach` | explicit "Try again" forces a re-attach |
| `permissionDeniedExplainsTheSession` | error copy is actionable, not raw Firestore text |
| `otherErrorsKeepTheirOwnDescription` | non-permission errors keep their own message |

### UITests — `ReleasedUITests`, 9/9 passing

New: `testLoadFailureOffersARecoverableRetry`. Drives the failure state offline
via `-MOCK_RELEASED -MOCK_RELEASED_ERROR`, asserts the screen does **not** show
Firestore's raw "Missing or insufficient permissions.", that a retry button
exists, and that tapping it leaves the error state and renders the recordings.
This is the test that reproduces the report offline; it fails against the old
code (no retry affordance existed at all).

## Caveat on the UITest run — read before trusting a red run

Other task workers were running `xcodebuild` against the **same** simulator
during this work. Effects observed, all environmental:

- Tests crashed with `Restarting after unexpected exit, crash, or test timeout`
  in a **different combination on each run**. The shifting set is the tell that
  it's contention, not a regression.
- An early run wrote to a generic `/tmp/ui2.log` that a sibling worker also
  wrote, so the log reported passes for test names that do not exist on this
  branch. Use a task-unique log path.

Every one of the 9 tests was observed passing; the two that crashed in the final
combined run (`testSendRecordingBundleToChatSheetOpens`,
`testUnsupportedFormatDownloadShowsMessage`) both pass in isolation and are
untouched by this change. The new test passed 4/4 across runs, including 2/2
solo.

## Not covered by tests

The server side. These tests prove the client **recovers** from a
`permission-denied`; they cannot prove the deployed Firestore ruleset actually
grants the read. See DEPLOY_STATUS.md and FOLLOW_UP.md.
