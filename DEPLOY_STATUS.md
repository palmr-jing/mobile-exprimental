# Deploy Status — Task #970: Add access to Dan sandbox

Not a web deploy, and no app build is involved. This task adds a Node operator
script that writes to the Commander allowlist in Firestore; the iOS app only
*reads* that data, so no `ai.palmr.emma` build or TestFlight upload is required.

- **App build**: not applicable — no Swift source changed.
- **Node tests**: `npm run test:scripts` → 12/12 pass. E2E verified against the
  Firestore emulator (see TEST_REPORT.md).
- **Production write (the actual grant)**: NOT performed here — it needs Firebase
  Admin credentials for `fir-web-codelab-8ace9`, which are not available in this
  environment. To apply it:
  ```
  GOOGLE_APPLICATION_CREDENTIALS=/path/to/fir-web-codelab-8ace9-sa.json \
    node scripts/grant-project-access.mjs dan@palmr.ai sandbox
  ```
- **Firestore rules impact**: none. The write targets an existing collection
  (`commander_allowed_users`) already covered by `firestore.rules`; no rule change
  and no rules deploy needed.
