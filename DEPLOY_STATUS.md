# Deploy status — task #1068

**Target:** TestFlight (iOS app `ai.palmr.emma`, ASC app id 6780673334)

**Deployed: NO — deliberately.**

## Build

Builds cleanly. Debug build for the iOS Simulator succeeded and both suites pass
(see TEST_REPORT.md). No archive was produced.

## Why no upload

The task was a bug report, not a release request. An upload burns a build number and costs
an archive + Apple processing round trip, so I left it for a human to trigger. The
prerequisite that CLAUDE.md cares about — a local simulator run that passes — is done, so
this is ready to ship whenever you want it.

To ship it:

```sh
# 1. Bump CURRENT_PROJECT_VERSION in project.yml (currently 20260719.1 — use 20260719.2)
# 2. Commit the bump, then:
ASC_ISSUER_ID=<uuid> scripts/upload-testflight.sh
```

## Firestore rules — NOT deployed from this repo

No rules change was made and none is needed on the evidence available: both
`firestore.rules` here and the source of truth at
`~/repos/experimental/commander/firestore.rules` already carry
`match /released_recordings/{id} { allow read, write: if request.auth != null; }`.

Do not deploy `firestore.rules` from this repo regardless — the copy here is a trimmed
subset for the emulator, and pushing it would drop every other Palmr collection's rules.

**Unverified:** I could not read the *live* deployed ruleset to confirm it matches the repo
(no `gcloud`, no non-interactive Firebase credential on this machine). See FOLLOW_UP.md.
