# Follow-up — #1069 [iOS] Can't access videos

**What was done**: The Videos tab was broken by a server-side change, not by the
app — another repo deployed its own `firestore.rules` to the shared Firebase
project at 03:43 UTC today, which replaced the whole ruleset and deleted the
`commander_videos` block, so every read was denied. I redeployed a merged ruleset
that restores the 23 deleted blocks without touching anything the other app added,
and separately fixed a client bug where the Videos tab could never recover from a
load failure without force-quitting the app.

**What needs review**:

- Open the Videos tab on the current TestFlight build — it should load without any
  app update. The fix is entirely server-side.
- Three other surfaces were broken by the same clobber and are also restored:
  the Released tab (`released_recordings`), Chat (`commander_channels`), and
  presence (`commander_presence`). Worth a quick check that each works.
- **`commander_tasks` project-level write protection is currently NOT enforced in
  production.** The live ruleset's copy predates it, and I deliberately did not
  overwrite it — see the next bullet. Decide whether that needs an urgent deploy.
- `output/rules-drift-report.md` lists 16 collections whose rules differ between
  `~/repos/experimental/commander/firestore.rules` and what was live. I left all
  16 alone. Neither side is uniformly right: the repo is newer for `commander_*`,
  but live is newer for `coach_users` / `coach_schedule_subscriptions` because the
  coach repo just deployed those. Someone who knows both apps has to pick per
  block — that judgement call is why I stopped rather than guessing.
- The new error copy ("Your account doesn't have access to videos right now. This
  is usually temporary — tap Try Again.") — check the tone is right, since the
  cause is on our side, not the user's.

**Action items**:

1. **Fix the root cause, or this recurs.** `~/repos/experimental/commander/firestore.rules`
   claims to cover all palmr apps but is missing every `coach_*`, `pt_*`, `fit_*`,
   `scan_results`, `ota_scan_results`, `palmr_preorders` and `auto_funding_requests`
   block. The next deploy from that repo re-breaks the iOS app; the next deploy
   from the coach repo re-breaks it again. Make one ruleset the real union and have
   both repos deploy that same file.
2. Reconcile the 16 divergent blocks (see report), then deploy the result.
3. Push this branch — I did not push.
4. Optional: ship the app change to TestFlight. It is not required to fix the
   reported bug and I did not bump `CURRENT_PROJECT_VERSION` or upload. Batch it
   with the next release.
5. Separately: `scripts/run-tests.sh` returns exit 0 even when the build fails
   outright. It hid a compile error from me during this task. Worth fixing.

Rollback for the rules deploy, if needed: re-release ruleset
`1f52c311-f185-4b16-ba91-36ead17f9b56`.

**Files changed**:

- `Sources/Services/VideoService.swift` — added `retry()`, which re-subscribes
  after a failure. Firestore kills a snapshot listener on permission-denied and
  never retries it, and `start(email:)` early-returns when the email hasn't
  changed, so the tab stayed stuck on the error for the whole session. Added
  `friendlyMessage(for:)` to map a rules denial to actionable copy.
- `Sources/Views/Videos/VideosView.swift` — the error state now shows a Try Again
  button; added `.accessibilityElement(children: .contain)` so the button stays
  queryable from XCUITest (the container's identifier was merging its children
  into one element and hiding it).
- `Sources/App/TestConfig.swift` — added the `-MOCK_VIDEOS_ERROR` launch-arg seam
  so the failure state is testable offline. Inert in production.
- `Tests/Unit/VideoTests.swift` — two cases covering the error-message mapping.
- `Tests/UITests/VideosUITests.swift` — `testLoadFailureOffersRetryAndRecovers`,
  which reproduces the reported screen offline and asserts recovery.
- `DEPLOY_STATUS.md`, `TEST_REPORT.md` — new.
- `output/rules-drift-report.md` — what was deleted, what was restored, and the 16
  blocks still needing a decision.
- `output/firestore-rules-deployed-1069.rules` — exact ruleset now in production.

No application source outside the Videos tab was touched, and this repo's
`firestore.rules` (an emulator-only vendored subset) was left alone — it already
had the correct `commander_videos` rule.
