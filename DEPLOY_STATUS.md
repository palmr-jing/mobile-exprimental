# Deploy status — #1072

**Target:** TestFlight (`ai.palmr.emma`, App Store Connect app id `6780673334`).

**Deployed:** No. Deliberately.

The task says this change is "batched to a build after review", so it stops at a
green local suite. Nothing was uploaded and `CURRENT_PROJECT_VERSION` was **not**
bumped — it is still `20260719.1`, the value on `main` from the previous batch.
Whoever cuts the next build should bump it then; two uploads with the same build
number are rejected.

**Build status:** Release-config archive not attempted. Debug builds for both
simulator destinations succeed, and the full test suite passes on iPhone 17 Pro
and iPad Air 11-inch M4 — see `TEST_REPORT.md`.

The only build warning is pre-existing and unrelated:
`Sources/Services/ChatService.swift:579: result of 'try?' is unused`.

## To ship this

```sh
# 1. Bump CURRENT_PROJECT_VERSION in project.yml (date stamp YYYYMMDD.N).
# 2. Re-run the suite locally — required before any upload.
xcodegen generate && scripts/run-tests.sh
# 3. Archive + upload.
ASC_ISSUER_ID=<uuid> scripts/upload-testflight.sh
```

Then poll for processing:

```sh
node scripts/asc.mjs GET "/v1/builds?filter[app]=6780673334&sort=-uploadedDate&fields[builds]=version,processingState"
```

Internal testers pick the build up automatically once it reports `VALID`.

## Firebase

No Firestore rules, Storage rules, or Hosting changes in this task, so nothing to
deploy there. (Note for whoever does touch `storage.rules` from this repo: it
replaces the whole bucket ruleset, which is shared with other Palmr repos.)
