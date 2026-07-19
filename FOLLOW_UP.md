# Follow-up — task #1068, "[iOS] Jing can't see anything"

## What was done

The Released tab hit a Firestore `permission-denied` and then stayed broken forever: the
listener was never re-attached, so Jing was stuck on "Missing or insufficient permissions."
until the app was force-quit. Made the failure recoverable (re-subscribe + a "Try again"
button) and replaced the raw SDK string with text that says what to do.

## The actual bug

The screenshot is Firestore's own wording for a rules rejection. The rules are not the
problem — both `firestore.rules` here and the source of truth at
`~/repos/experimental/commander/firestore.rules` already allow
`read: if request.auth != null` on `released_recordings`, and have since task/965. So the
first denial was an auth-token condition on Jing's device.

What turned a transient denial into a dead screen was the client:

1. `ReleasedRecordingsService.started` latched to `true` and was only cleared by `stop()`,
   which the view never called. **Firestore permanently tears down a snapshot listener that
   fails with permission-denied — it does not retry.** So there was no re-subscribe for the
   life of the process.
2. `.task(id: auth.currentUser?.uid)` called `start()` but never `stop()`, so even signing
   out and back in as another user reused the dead listener. `VideoService` already got this
   right by keying on `currentEmail` and calling `stop()` first; this service didn't.
3. No retry affordance, and a raw SDK string that gave the user nothing to act on.

Whatever caused the first denial, the tab could not recover. That's what's fixed.

## What needs review

- **The message wording.** "Your account doesn't have access to released recordings yet. Try
  again, or sign out and back in — if it keeps happening, ask an admin to check your access."
  Check that "ask an admin" is the right escalation for a gym user like Jing, and that this
  is the tone you want.
- **Retry is user-driven on purpose.** I did not add automatic re-subscribe on tab
  re-appearance — with a genuinely denied account that would hammer Firestore on every tab
  switch. If you'd rather it self-heal, the hook is `service.retry()`.
- **Confirm the live ruleset actually matches the repo.** I could not read it: no `gcloud`
  and no non-interactive Firebase credential on this machine. If the deployed ruleset is
  missing the `released_recordings` rule, this fix makes the error legible and retryable but
  retry will keep failing — the rule would need deploying from
  `~/repos/experimental/commander` (**not** from this repo; the copy here is a trimmed
  emulator subset and deploying it would drop other collections' rules).
- **Ask Jing whether it's now working**, or whether she still can't get past the retry. That
  distinguishes "stale token, fixed" from "genuinely not provisioned".
- `Sources/Design/DesignSystem.swift` — `EmptyStateView`'s action button now has an
  accessibility identifier. Shared component; check nothing else queries it by label.

## Known gap I did not fix

`VideosView` / `VideoService` has the same no-retry dead end on the Videos tab: a
permission-denied there is equally unrecoverable, and it shows the same raw string. It's
outside this task's scope so I left it, but it's the same one-line class of fix and Jing
could hit it next. Worth a ticket.

## Action items

- [ ] Push the branch (the worker does this automatically).
- [ ] Verify the deployed Firestore ruleset contains the `released_recordings` read rule.
- [ ] Decide whether to ship to TestFlight. Not uploaded — see DEPLOY_STATUS.md. Bump
      `CURRENT_PROJECT_VERSION` in `project.yml` to `20260719.2` first.
- [ ] Ask Jing to confirm the tab loads after updating.
- [ ] Consider a ticket for the same retry gap on the Videos tab.

## Files changed

| File | Change |
| --- | --- |
| `Sources/Services/ReleasedRecordingsService.swift` | Replaced the `started` latch with a `currentUID` key so a new user re-subscribes; added `retry()`; drop the dead listener handle on error; added `message(for:)` translating `permission-denied` / `unauthenticated` / `unavailable` into actionable text. |
| `Sources/Views/Recordings/ReleasedRecordingsView.swift` | Error state now renders via `EmptyStateView` with a "Try again" action; `.task` passes the uid to `start(uid:)`; added the `-MOCK_RELEASED_ERROR` seam plumbing. |
| `Sources/App/TestConfig.swift` | Added `isMockReleasedError` (`-MOCK_RELEASED_ERROR`), which implies `isMockReleased` so retry recovers onto the existing fixtures. |
| `Sources/Design/DesignSystem.swift` | Gave `EmptyStateView`'s action button the `empty-state-action` identifier so UITests can tap it. |
| `Tests/Unit/ReleasedRecordingsErrorTests.swift` | New — 5 tests over the error-message mapping. |
| `Tests/UITests/ReleasedUITests.swift` | Added 2 tests: the failure screen is actionable, and retry recovers the list. |
| `TEST_REPORT.md`, `DEPLOY_STATUS.md`, `FOLLOW_UP.md` | New. |
| `output/released-error-fixed.png` | Screenshot of the fixed screen, to compare against the reported one. |

## Note on the test run

My first UITest run showed two failures that were **not real** — another worker's build
(`.worktrees/task-1070`) was on the same booted simulator under the same bundle id, and my
tests never ran. Re-ran on a dedicated simulator with a private derived-data path: all 10
`ReleasedUITests` pass. Details in TEST_REPORT.md. Worth isolating by default when workers
run concurrently.
