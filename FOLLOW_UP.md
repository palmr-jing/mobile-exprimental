# Follow-Up — Task #970: Add access to Dan sandbox

**What was done**: Corrected the production email to `dan@palmr.ai` (the user
confirmed it) in `scripts/grant-project-access.mjs` — both the usage example and the
`--help` error line now read `dan@palmr.ai dan`. The emulator seed and unit tests
already used `dan@palmr.ai`, so no change was needed there. The grant itself is
unchanged: it writes Dan's `commander_allowed_users` allowlist doc scoped to the `dan`
project (`https://manage.everbot.org/dan`). All 12 unit tests still pass.

---

## Answering the direct question: "Will this give access to the functionality of `https://manage.everbot.org/dan` on the Emma iOS app?"

Short answer: **it grants Dan the correct allowlist record, but it does not, by
itself, put the web console's functionality into the Emma iOS app.** Two different
things are being conflated. Details, because this matters:

1. **The Emma iOS app is a different, narrower client than the web console.**
   `manage.everbot.org/dan` is the full commander web console for the `dan` project.
   The Emma app is a separate mobile client on the same Firebase backend, and it only
   surfaces: Ask Emma, Chat, the Videos tab, and a read-mostly dashboard
   (tasks/projects/workers). Granting the `dan` project does not add the console's
   features to the app — those screens don't exist in the app to unlock.

2. **The app does not currently gate content by project scope.** The scoping logic
   (`Access.canAccessProject` / `Access.accessibleProjects` in `Sources/Logic/Access.swift`)
   is implemented and unit-tested, but a repo-wide search shows it is **not called by
   any View or by `FirestoreService`.** `DashboardView` groups *all* tasks it loads;
   `FirestoreService` does not filter by `account.projects`. So adding `['dan']` to
   Dan's doc neither unlocks nor restricts any screen on the client side today.

3. **The Videos tab — where this was reported — is scoped by email, not by project.**
   `VideoService.start(email:)` loads `commander_videos` where `assigned_emails`
   contains Dan's address (`VideosView.swift:64-65`). Dan will only see reels or
   recordings explicitly *released to his email* from `manage.everbot.org`. The
   project grant does not change what appears on the Videos tab.

4. **The one enforced backend boundary reads a different collection than this script
   writes.** In `firestore.rules`, `canAccessProject()` (which gates
   `commander_tasks` create/update/delete) reads
   `commander_user_projects/{uid}` — keyed by Firebase **UID**. This script writes
   `commander_allowed_users/{emailDocId}` — keyed by **email**. These are two separate
   stores. So even the single rule that enforces project access is *not* fed by this
   grant. Caveat: `firestore.rules` here is a vendored subset (its header points to
   `~/repos/experimental/commander/firestore.rules` as the source of truth), so the
   production rules may differ — but on the evidence in this repo, the grant and the
   enforced boundary are wired to different collections.

**Net**: the grant is the right, necessary bookkeeping — it lists Dan with the `dan`
scope in the allowlist the app reads for identity and the web console reads for
access. It is **not sufficient** to reproduce "the functionality of
`manage.everbot.org/dan`" inside the Emma iOS app. Getting real backend enforcement
for Dan likely also needs a `commander_user_projects/{his-uid}` entry, and that lives
in the commander repo, not here.

---

**What needs review** (before assuming Dan is fully set up):
- Confirm, in the commander repo (`~/repos/experimental/commander`), which collection
  production actually reads for access: `commander_allowed_users` (email-keyed, what
  this script writes) or `commander_user_projects` (uid-keyed, what the vendored rules
  read), or both. If the backend needs `commander_user_projects/{uid}`, that entry
  still has to be created — this script does not create it, and a UID isn't known
  until Dan has signed in at least once.
- Confirm the project slug is exactly `dan` (last path segment of
  `https://manage.everbot.org/dan`) and matches Commander's repo registry.
- The "never narrow access" guard is intentional: if Dan is already an admin or
  already unrestricted (`projects: null` / `['*']`), the script skips rather than
  replacing his access with just `['dan']`.

**Action items** (require a human with production access):
- Run the grant against production (needs Firebase Admin creds for
  `fir-web-codelab-8ace9`):
  ```
  GOOGLE_APPLICATION_CREDENTIALS=/path/to/sa.json \
    node scripts/grant-project-access.mjs dan@palmr.ai dan
  ```
  It prints the before/after project list and is safe to re-run (idempotent).
- Decide whether Dan also needs a `commander_user_projects/{uid}` entry for backend
  enforcement (see "What needs review"). That is a commander-repo step, not this repo.
- Push the `task/970-...` branch (the worker pushes automatically after the task).
- Tell Dan to sign out/in on the Emma iOS app so `AuthService` re-reads his allowlist
  doc. (This refreshes his identity/display; per the notes above it does not, on its
  own, add web-console features to the app.)

**Files changed** (this run):
- `scripts/grant-project-access.mjs` — production email corrected from
  `dan@everbot.org` to `dan@palmr.ai` (usage comment + `--help` error line). No logic
  change.
- `FOLLOW_UP.md` — corrected the email note and added a direct, honest answer to
  whether this grant delivers the web console's functionality on the iOS app.
