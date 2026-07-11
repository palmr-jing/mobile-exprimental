# Test Report — Task #974 ([iOS] No file upload on iOS app)

## The fix and how it was verified
The bug was a missing **Firebase Storage security rule** for `chat-uploads/…` on
the production bucket, so authenticated uploads were rejected with
`storage/unauthorized`. The fix is a rules deploy (see `DEPLOY_STATUS.md`). No
Swift source changed, so the primary verification is at the rules layer, not the
app binary.

### Rules verification (authoritative for this fix)
Ran the Firebase Rules **test** API against the deployed `storage.rules` source,
simulating the exact path the app writes (`chat-uploads/{channelId}/{ts}-{name}`):

- authed write → **ALLOW** (was previously denied — this is the fix)
- anonymous write → **DENY**
- authed read (image display) → **ALLOW**
- authed write to an unrelated path → **DENY** (least privilege preserved)

Also confirmed via the Rules Releases API that the released ruleset is bound to
`firebase.storage/fir-web-codelab-8ace9.firebasestorage.app` (the bucket the iOS
app uses) and contains all six live paths: `image_diffs`, `task-attachments`,
`wallcam`, `wallcam_highlights`, `experimental_videos`, `chat-uploads`.

## iOS unit tests
- **Suites** (`Tests/Unit/`): Access, ChatPagination, ChatShare, Presence, Video,
  ReelExport, ReportIssue, SpeechRecognitionService, ReleasedRecording — unchanged
  by this task (no Swift touched).
- **How to run**:
  ```bash
  SKIP_EMULATOR=1 scripts/run-tests.sh    # unit only, hermetic
  ```
- **Status**: PASS — `Test run with 65 tests in 9 suites passed` (iPhone 17 Pro
  simulator, `SKIP_EMULATOR=1 scripts/run-tests.sh`). Nothing regressed; this task
  touched no Swift.

## Notes
- There is no XCUITest that exercises a Storage upload (the emulator UI tests
  don't cover the paperclip → putData path), so the emulator run does not
  regression-test this fix. The Rules test API above is the direct check.
- The shared `storage.rules` file now also feeds the test emulator; it compiled
  cleanly (Firebase compiled it on deploy) and adds no path the UI tests depend on.
