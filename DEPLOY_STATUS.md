# Deploy Status — Task #974 ([iOS] No file upload on iOS app)

**This task's fix is a Firebase Storage rules deploy, and it IS deployed to
production.** No app binary change was needed — the bug was server-side, so the
fix takes effect immediately for every existing install (no TestFlight rebuild).

## What was deployed
- **Target**: Firebase Storage rules for project `fir-web-codelab-8ace9`,
  bucket `fir-web-codelab-8ace9.firebasestorage.app` (the exact bucket the iOS
  app's `GoogleService-Info.plist` points at).
- **Command**: `firebase deploy --only storage --project fir-web-codelab-8ace9`
  (run via `npx firebase-tools`, CLI already authenticated on this machine).
- **Result**: `Deploy complete!` — rules compiled and released.
- **Live ruleset**: `82cef32f-4255-47d7-ba93-1d94d0cc030b`, released
  2026-07-11T14:41Z to `firebase.storage/fir-web-codelab-8ace9.firebasestorage.app`.

## Verification (server-side, authoritative)
Queried the Firebase Rules API to confirm the released ruleset is bound to the
right bucket and contains every path. Then ran the Rules **test** API against the
live source for the exact path the app writes:

| Simulated request                                             | Outcome |
|---------------------------------------------------------------|---------|
| authed `create` `chat-uploads/general/<ts>-upload.jpg`        | ALLOW ✓ |
| anonymous `create` same path                                  | DENY ✓  |
| authed `get` (read for display) same path                     | ALLOW ✓ |
| authed `create` an unrelated path                             | DENY ✓  |

The authed-write ALLOW is the fix: uploads that previously returned
`storage/unauthorized` are now authorized.

## iOS app shipping (unchanged, not needed for this fix)
The app ships via Xcode Archive → TestFlight (`scripts/upload-testflight.sh`),
not a hosting target. No archive was produced for this task because no Swift
changed. `CURRENT_PROJECT_VERSION` was NOT bumped for the same reason.
