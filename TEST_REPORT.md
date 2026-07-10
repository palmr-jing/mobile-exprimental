# Test Report — Task #970: Add access to Dan sandbox

## What was tested

### 1. Allowlist-merge unit tests (new)
`scripts/grant-project-access.test.mjs` — 12 tests over the pure `planGrant`
merge logic (no Firestore, no network):

- doc-id / display-name derivation
- absent doc → creates a scoped doc
- scoped user → project appended, sorted, de-duped
- already-has-project → skip (idempotent)
- admin and unrestricted users (`projects: null`, `['*']`) are **left untouched** —
  a scoped grant must never narrow existing access
- the caller's `projects` array is not mutated
- malformed `projects` and missing args throw instead of corrupting data

Run:
```
npm run test:scripts      # node --test scripts/*.test.mjs
```
Status: **12 passed, 0 failed.**

### 2. End-to-end against the Firebase Firestore emulator
Drove the real CLI (`scripts/grant-project-access.mjs`) against a live emulator
via `firebase-tools emulators:exec`:

- Seeded `dan@palmr.ai` with `projects: ['palmr-ios']`.
- Run 1 → `["palmr-ios","sandbox"]` — sandbox added, existing project kept.
- Run 2 → no-op ("already has sandbox"), still `["palmr-ios","sandbox"]`.

Status: **PASS** — sandbox granted, prior access preserved, idempotent, no dupes.

### 3. Syntax / smoke checks
- `node --check` on both edited scripts — clean.
- CLI with no args prints usage and exits 1 (the Firebase Admin SDK is imported
  lazily, so that path needs no credentials or network).

## Not run
- Xcode unit/UI tests: this task touches only Node ops scripts (`scripts/*.mjs`)
  and `package.json`. No Swift source changed, so the iOS test suite is unaffected
  and was not rebuilt.
- Production write: requires Firebase Admin credentials for the live project
  `fir-web-codelab-8ace9` (see FOLLOW_UP.md). Verified against the emulator instead.
