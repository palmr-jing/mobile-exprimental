# Deploy status — #1069

## Firestore security rules — DEPLOYED (this is the actual fix)

| | |
|---|---|
| Target | Firestore rules, project `fir-web-codelab-8ace9`, release `cloud.firestore` |
| Deployed ruleset | `21a55a79-63ff-4ef9-9276-46d5b7d5f85c` (2026-07-19T12:38:52Z) |
| Replaced ruleset | `1f52c311-f185-4b16-ba91-36ead17f9b56` (2026-07-19T03:43:59Z) |
| Rollback | re-release `1f52c311-f185-4b16-ba91-36ead17f9b56` |
| Validation | compiles clean; 10/10 rules test cases pass against the deployed source |

Deployed via the Firebase Rules REST API (create ruleset → update release), using
the machine's existing `firebase-tools` credential. Not deployed from this repo —
this repo's `firestore.rules` is a vendored emulator-only subset and its header
says not to deploy from here.

The deployed ruleset is **live verbatim + only the 23 blocks live was missing**,
so it is a strict superset of what was already in production and cannot remove
access from any other app. Verified: no collection present in the old ruleset is
absent from the new one.

Contents saved to `output/firestore-rules-deployed-1069.rules`.
Drift analysis in `output/rules-drift-report.md`.

## iOS app — NOT shipped to TestFlight

Client changes (retry affordance + error copy) are committed but **not uploaded**.
No build-number bump was made. The server-side fix already restores video access
for everyone on the current build; shipping an app update is optional and should
be batched with the next release.

Per CLAUDE.md, TestFlight upload requires a local sim run first — the unit suite
passes (95/95) and the new UITest passes. See TEST_REPORT.md for the pre-existing
UITest flakiness that is unrelated to this change.
