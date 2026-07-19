# Deploy status — task #1070

**Target:** TestFlight (iOS app). Not a web project; no hosting deploy applies.

**Build:** passing. `xcodegen generate` + unit suite + `ReleasedUITests` all run
clean on the iOS Simulator (see TEST_REPORT.md).

**Deployed:** nothing. No TestFlight upload was made and no build number was
bumped — `CURRENT_PROJECT_VERSION` in `project.yml` is untouched at
`20260719.1`, the value already shipped in commit 4cc3cb2. Uploading is a human
call: it burns a build number and the fix should be reviewed first.

To ship it:

```sh
# bump CURRENT_PROJECT_VERSION in project.yml (e.g. 20260719.2), commit, then:
ASC_ISSUER_ID=<uuid> scripts/upload-testflight.sh
```

## Firestore rules — NOT deployed, and NOT verified

This branch changes **no** rules. `firestore.rules` in this repo is the vendored
emulator copy and is explicitly not deployed from here; the source of truth is
`~/repos/experimental/commander/firestore.rules`.

I could not verify what is actually live. `firebase firestore:rules:get` is not
a command in firebase-tools 15.x, and there is no `gcloud` credential on this
machine to hit the Firebase Rules REST API. So this is **unverified**:

- The source-of-truth file **does** contain the needed rule
  (`match /released_recordings/{id} { allow read, write: if request.auth != null; }`),
  added in `5e99be1` for task #965 and reconciled against live in `24d376a`.
- Whether the *deployed* ruleset matches that file is unconfirmed.

If the deployed ruleset has drifted, the client fix here does not resolve the
report — it makes the failure recoverable and legible, but a genuine server-side
denial will simply fail again on retry. See FOLLOW_UP.md for the check.
