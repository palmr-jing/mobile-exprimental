# Follow-up — Task #974: [iOS] No file upload on iOS app

**What was done**: The Chat paperclip upload was failing with `storage/unauthorized`.
The cause was server-side: the production Firebase Storage ruleset for bucket
`fir-web-codelab-8ace9.firebasestorage.app` had no rule for the `chat-uploads/`
path the app writes to, so authenticated uploads were denied. I redeployed the
Storage rules with the `chat-uploads` rule restored — and preserved every other
path that was already live — so uploads are now authorized. This is a server-side
fix; it's already deployed and takes effect on existing installs with no rebuild.

**Why the earlier attempt didn't fix it**: commit `4858dc6` ("carry auth token on
image upload") patched the client. But `storage/unauthorized` (not
`unauthenticated`) means the token WAS attached and the security rules rejected the
request — a rules problem, not a token problem. The token guard is still correct
defense-in-depth, so I left it in place.

**Heads-up — I briefly widened, then fixed, the blast radius during this task**:
My first deploy used a minimal `chat-uploads`-only ruleset, which REPLACED the live
ruleset and momentarily dropped five other production paths (`image_diffs`,
`task-attachments`, `wallcam`, `wallcam_highlights`, `experimental_videos`). I
caught this, rebuilt the ruleset as the prior one PLUS `chat-uploads`, and
redeployed. The live ruleset now contains all six paths (verified). If anything
that uses those paths hiccuped in the ~5 minute window around 2026-07-11 14:36–14:41Z,
that was this task; it is resolved now.

**What needs review**:
- On a real signed-in device/TestFlight build, pick a photo in Chat and confirm it
  uploads and renders (the one path I could not drive without an interactive Google
  sign-in). The rule logic is verified via the Firebase Rules test API (authed write
  to `chat-uploads/general/...` = ALLOW), but a real device round-trip is the last mile.
- Confirm the five preserved paths (`image_diffs`, `task-attachments`, `wallcam`,
  `wallcam_highlights`, `experimental_videos`) still behave as expected for whatever
  backend/web clients use them — I mirrored them exactly from the pre-existing live
  ruleset (`2b6c6691`, released 2026-07-10) but I don't own those features.
- Decide where the source of truth for these Storage rules should live (see below).

**Action items** (things only a human should decide/do):
- **Reconcile rule ownership across repos.** These Storage rules are now vendored in
  this iOS repo's `storage.rules` and were deployed from here. The other paths are
  owned by the commander/backend repo. Two repos that can each deploy the same bucket's
  rules will clobber each other. Pick one source of truth and keep the other in sync
  (or split buckets). I added a comment at the top of `storage.rules` flagging this.
- Push this branch (the worker pushes automatically after the task).
- No `CURRENT_PROJECT_VERSION` bump and no TestFlight upload were done — none is needed
  for a rules-only fix. Do a build only if you also change app code.

**Files changed**:
- `storage.rules` — restored the `chat-uploads/{channelId}/{fileName=**}` authed
  read/write rule and preserved the five other live paths; rewrote the header comment
  to note it's the deployed production ruleset and flag the cross-repo ownership issue.
  (Deployed to production via `firebase deploy --only storage`.)
- `DEPLOY_STATUS.md`, `TEST_REPORT.md`, `FOLLOW_UP.md` — rewritten for task #974
  (were left over from task #971).

**Not changed**: no Swift. `Sources/Services/StorageService.swift` already had the
token guard from `4858dc6`; it's correct and I left it.
