# Test report — task #1068 ([iOS] Jing can't see anything)

## Status: PASSING

## What was run

### Unit suite (Swift Testing) — 98 tests, 12 suites, all passing

```sh
SKIP_EMULATOR=1 scripts/run-tests.sh
```

New suite `Tests/Unit/ReleasedRecordingsErrorTests.swift` (5 tests, all passing) covers
`ReleasedRecordingsService.message(for:)`:

| Test | Asserts |
| --- | --- |
| `permissionDeniedBecomesActionableText` | The exact error in the report's screenshot no longer reaches the user as "Missing or insufficient permissions." |
| `unauthenticatedUsesTheSameGuidance` | An expired/absent token gets the same remedy |
| `unavailableReadsAsAConnectionProblem` | Offline reads as a connection problem, not an access problem |
| `unrecognisedFirestoreCodeKeepsItsOriginalText` | Unknown Firestore codes stay diagnosable |
| `nonFirestoreErrorKeepsItsOriginalText` | Non-Firestore errors pass through untouched |

`message(for:)` is `nonisolated static`, so these run without constructing the service —
no `Firestore.firestore()`, no configured FirebaseApp needed in the hermetic unit host.

### UITests (XCUITest) — `ReleasedUITests`, 10 tests, all passing

No Firebase emulator needed; driven entirely by the `-MOCK_RELEASED*` launch-arg seams.

```sh
xcodebuild test -scheme MobileCommander \
  -destination 'id=<dedicated-sim-udid>' \
  -derivedDataPath /tmp/dd-1068 \
  -only-testing:MobileCommanderUITests/ReleasedUITests
```

Two new tests reproduce the report offline via `-MOCK_RELEASED_ERROR`:

- `testPermissionFailureShowsActionableMessage` — the failure screen shows guidance and a
  "Try again" button, and the raw Firestore string is gone.
- `testRetryAfterPermissionFailureRecoversTheList` — tapping retry re-subscribes and lands
  on the recordings. This is the regression guard for the actual bug: before the fix there
  was no way off that screen short of force-quitting the app.

### Manual check

Installed the built app on a clean simulator and launched with
`-UITEST -MOCK_RELEASED_ERROR`; screenshot at `output/released-error-fixed.png` for
side-by-side comparison with the reported `attachments/screenshot.png`.

## ⚠️ Simulator isolation — read this before trusting a red run

The first UITest run reported two failures. They were **not real**: the log cited
`/Users/jc/repos/mobile-exprimental/.worktrees/task-1070/...` and a test name
(`testLoadFailureOffersARecoverableRetry`) that does not exist in this worktree. Another
worker was driving the same booted simulator with the same bundle id (`ai.palmr.emma`), and
the test session got crossed — this worktree's new tests never ran at all.

Re-running against a purpose-created simulator with a private `-derivedDataPath` gave a
clean pass on all 10 tests. When workers run concurrently, isolate before believing a
failure:

```sh
SIM=$(xcrun simctl create "task-sim" "iPhone 17 Pro")
xcodebuild test -scheme MobileCommander -destination "id=$SIM" -derivedDataPath /tmp/dd-<task>  ...
xcrun simctl delete "$SIM"
```

The temporary simulator and derived data created for this run were deleted afterwards.

## Not verified

The deployed production Firestore ruleset could not be read — no `gcloud` on this machine
and no non-interactive Firebase credential. See FOLLOW_UP.md.
