# Follow-Up — Task #970: Add access to Dan sandbox

**What was done**: Retargeted the existing operator grant to match the URL the user
gave — `https://manage.everbot.org/dan`. The web console routes each project at
`/<slug>`, so that URL identifies the project whose slug is `dan`. The grant now
encodes *Dan gets the `dan` project* (previously `sandbox`). Access lives in the
Firestore `commander_allowed_users` allowlist, which the iOS app only reads, so this
stays an operator action run through `scripts/grant-project-access.mjs`, not an app
code change. The merge logic is unit-tested (12 cases, all passing) and the emulator
seed now reflects the same end state (Dan scoped to `dan`, plus a `dan` repo).

Why a script and not in-app UI: `AuthService` reads `commander_allowed_users` but
nothing in the app writes it, and it shouldn't — the rules' source of truth lives in
the commander repo (`firestore.rules` here is a vendored read-only subset), and grants
have always been an operator step (see `add-internal-testers.mjs`, `seed-emulator.mjs`).
"Through the iOS app" is where the request came from and where Dan will *see* the
project after the grant; it is not a place the app can write the allowlist.

Email domain — read before running against production: the console and the real
human accounts use `@everbot.org` (e.g. `jing@everbot.org`, `tim@everbot.org`), so the
production command below defaults to `dan@everbot.org`. The emulator seed keeps
`dan@palmr.ai` because every local fixture user is on the `palmr.ai` test domain. If
Dan's real sign-in email differs, change the one CLI argument — the script is general.

**What needs review**:
- Confirm the project slug is exactly `dan` (the last path segment of
  `https://manage.everbot.org/dan`) and that it matches Commander's repo registry.
- Confirm Dan's production sign-in email. Defaulted to `dan@everbot.org` (console
  domain); the prior run had guessed `dan@palmr.ai`.
- The "never narrow access" guard is intentional: if Dan is already an admin or
  already unrestricted (`projects: null` / `['*']`), the script skips rather than
  replacing his access with just `['dan']`.

**Action items** (require a human with production access):
- Run the grant against production (needs Firebase Admin creds for
  `fir-web-codelab-8ace9`):
  ```
  GOOGLE_APPLICATION_CREDENTIALS=/path/to/sa.json \
    node scripts/grant-project-access.mjs dan@everbot.org dan
  ```
  It prints the before/after project list and is safe to re-run (idempotent).
- Push the `task/970-...` branch (the worker pushes automatically after the task).
- Tell Dan to sign out/in on the Emma iOS app so `AuthService` re-reads his allowlist
  doc and the `dan` project scope takes effect.

**Files changed**:
- `scripts/grant-project-access.mjs` — usage examples retargeted to the `dan`
  project (and `dan@everbot.org` for the production example); added a note that the
  `<project>` arg is the console URL slug. No logic change.
- `scripts/grant-project-access.test.mjs` — fixture project `sandbox` → `dan`;
  updated the expected merge result to `['dan', 'palmr-ios']` (sorted — `dan` sorts
  before `palmr-ios`) and the already-has-it / malformed cases to match.
- `scripts/seed-emulator.mjs` — Dan scoped to `projects: ['dan']` and the seeded repo
  registry entry changed from `sandbox` to `dan`.
- `FOLLOW_UP.md`, `TEST_REPORT.md` — updated to reflect the `dan` project and the
  email-domain note.
