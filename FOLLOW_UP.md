# Follow-Up — Task #970: Add access to Dan sandbox

**What was done**: Added a Node operator script that grants a user access to a
Commander project by writing the `commander_allowed_users` allowlist in Firestore,
and used it to encode the intended change — `dan@palmr.ai` gets the `sandbox`
project. Access is stored server-side (the iOS app only reads it), so the grant is
an operator action, not an app code change. The script's merge logic is unit-tested
and was verified end-to-end against the Firebase emulator. The emulator seed now
reflects the same end state (Dan + a `sandbox` repo) for local dev and tests.

Why a script rather than in-app UI: `AuthService` reads `commander_allowed_users`
but nothing in the app writes it — grants have always been an operator step, and
the repo already keeps that kind of tooling in `scripts/` (`add-internal-testers.mjs`,
`seed-emulator.mjs`). This follows that pattern.

Note on interpretation: "Dan sandbox" was read as *grant Dan (dan@palmr.ai) access
to the `sandbox` project*. If it instead meant a differently-named project (or a
different person), just change the two CLI arguments — the script is general.

**What needs review**:
- Confirm the intended grant is `dan@palmr.ai` → project `sandbox` (vs. a different
  email or project name). The script takes both as arguments, so it's a one-line change.
- Confirm `sandbox` is the exact project/repo name used in Commander's registry.
- Review that the "never narrow access" guard is the desired behavior: if Dan is
  already an admin or already unrestricted (`projects: null`/`['*']`), the script
  skips rather than replacing his access with just `['sandbox']`.

**Action items** (require a human with production access):
- Run the grant against production (needs Firebase Admin creds for
  `fir-web-codelab-8ace9`):
  ```
  GOOGLE_APPLICATION_CREDENTIALS=/path/to/sa.json \
    node scripts/grant-project-access.mjs dan@palmr.ai sandbox
  ```
  It prints the before/after project list and is safe to re-run (idempotent).
- Push the `task/970-...` branch (the worker pushes automatically after the task).
- Tell Dan to sign out/in on the Emma iOS app so `AuthService` re-reads his allowlist
  doc and the new project scope takes effect.

**Files changed**:
- `scripts/grant-project-access.mjs` — new. Idempotent allowlist grant: merges a
  project into a user's `commander_allowed_users` doc (creating it if absent), never
  narrows an admin/unrestricted user, targets `fir-web-codelab-8ace9` by default and
  the emulator when `FIRESTORE_EMULATOR_HOST` is set. Firebase Admin SDK is imported
  lazily so the pure `planGrant`/`docId` helpers are importable and testable alone.
- `scripts/grant-project-access.test.mjs` — new. 12 `node:test` cases for the merge logic.
- `scripts/seed-emulator.mjs` — added `dan@palmr.ai` (`projects: ['sandbox']`) to the
  allowlist and registered a `sandbox` repo, so fixtures match the intended state.
- `package.json` — added a `test:scripts` script (`node --test scripts/*.test.mjs`).
