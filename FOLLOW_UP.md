# Follow-up — task #1070 ([iOS] Can't load recordings)

**What was done**: The Released tab's Firestore subscription guarded on a
one-shot `started` flag that nothing ever reset, so a single `permission-denied`
left the screen dead forever — Firestore tears the snapshot listener down on
error and nothing ever re-attached. The subscription is now keyed on the
signed-in uid (matching how `VideoService` already keys on email), a dead
listener re-attaches on the next visit, the error state offers a "Try again"
button, and the copy explains a stale session instead of echoing Firestore's
"Missing or insufficient permissions."

## Read this first — the fix may not be the whole story

I could **not** verify the deployed Firestore rules, so I can't prove this
closes the report. Two things could produce the reported screen:

1. **A transient/stale auth token** (listener attached before the token
   propagated, or one that outlived a sign-out). This branch fixes that — and
   fixes the fact that it was permanent.
2. **The deployed ruleset genuinely denies the read.** This branch does *not*
   fix that. It only makes the failure recoverable and legible.

The rules source of truth (`~/repos/experimental/commander/firestore.rules`) has
the right rule and has since #965, so (1) is the more likely cause — but that is
inference, not verification. `firebase firestore:rules:get` doesn't exist in
firebase-tools 15.x and there's no `gcloud` credential here.

**Please confirm which it is** before assuming this is closed:

```sh
gcloud auth login
TOKEN=$(gcloud auth print-access-token)
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://firebaserules.googleapis.com/v1/projects/fir-web-codelab-8ace9/releases"
# then fetch the ruleset it names and confirm it contains released_recordings
```

If it's missing, deploy from `~/repos/experimental/commander` (**not** from this
repo — this repo's `firestore.rules` is the vendored emulator subset, and
deploying it would replace the whole bucket ruleset).

## What needs review

- The retry semantics in `ListenerGate.shouldAttach(for:)`: a **failed** listener
  re-attaches whenever the view's `.task` re-fires (i.e. on tab revisit or
  identity change), not on a timer. Confirm you're happy with that cadence —
  it's deliberately not an automatic retry loop, so a hard denial can't spin.
- The new error copy in `ReleasedRecordingsService.sessionExpiredMessage`:
  "Your session expired before the recordings could load. Try again, or sign out
  and back in." It asserts a stale session, which is the correct reading for a
  `request.auth != null` rule — but it would read as misleading if the real cause
  turns out to be (2) above.
- `ReleasedRecordingsView.empty(...)` now omits the `released-empty`
  accessibility identifier when the state has a button. A container-level
  identifier propagates down and hides the child button from XCUITest (the trap
  already documented on `RecordingCard`) — and an empty-string identifier still
  creates the flattening container, which is what made my first attempt fail.
  Nothing referenced `released-empty`, so this breaks no existing test.
- Whether the same one-shot-flag pattern exists in other services. I checked
  `VideoService` (already keyed on email, fine) but did not audit `ChatService`,
  `NotificationService`, or `Presence`.

## Action items

- Verify the deployed Firestore ruleset (command above) — this is the one thing
  that decides whether the report is actually closed.
- Ask the reporter whether force-quitting the app made the Released tab work
  again. If yes, that confirms cause (1) and this branch is the fix.
- Bump `CURRENT_PROJECT_VERSION` in `project.yml` and run
  `ASC_ISSUER_ID=<uuid> scripts/upload-testflight.sh` when you want this on
  TestFlight. I did not bump or upload.
- Push the branch (I did not push).

## Files changed

- `Sources/Logic/ListenerGate.swift` — **new**. Pure value type deciding when a
  snapshot listener must be (re)attached; keyed on identity, treats a failed
  listener as detached. Extracted so the logic is testable without Firestore.
- `Sources/Services/ReleasedRecordingsService.swift` — `start()` → `start(uid:)`
  backed by `ListenerGate`; added `retry(uid:)`; `stop()` now resets state;
  errors mark the listener dead and drop the handle; added the pure
  `message(for:)` permission-denied mapping.
- `Sources/Views/Recordings/ReleasedRecordingsView.swift` — error state gains a
  "Try again" action; `.task` passes the uid and tears down on sign-out; `empty`
  helper takes an optional action and no longer clobbers the button's identifier.
- `Sources/Design/DesignSystem.swift` — gave `EmptyStateView`'s action button the
  `empty-action` accessibility identifier so UITests can find it.
- `Sources/App/TestConfig.swift` — added the `-MOCK_RELEASED_ERROR` seam.
- `Tests/Unit/ListenerGateTests.swift` — **new**. 8 tests over the gate's
  lifecycle and the error copy.
- `Tests/UITests/ReleasedUITests.swift` — added
  `testLoadFailureOffersARecoverableRetry`.
- `MobileCommander.xcodeproj/project.pbxproj` — `xcodegen generate` output for
  the two new files.
- `TEST_REPORT.md`, `DEPLOY_STATUS.md` — new.
