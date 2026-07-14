# Follow-Up — Task #970: Add access to Dan sandbox

**What was done**: Built the `manage.everbot.org/dan` console *into* the Emma iOS
app as a new, project-scoped **"Projects" tab**. The app already contained a full
Swift port of the Commander console (`DashboardView` + tasks/workers/progress under
`Sources/Views/Developer/`), but it was orphaned — `RootTabView` only wired Ask
Emma / Chat / Videos, and the `Access` project-scoping was never called. This run
wires that console in, gated and scoped by the signed-in user's allowlist grant, so
Dan (granted `dan`) opens the app and sees the `dan` sandbox's dashboard. The grant
script from the earlier passes is unchanged.

## How it behaves

- **Gated tab.** A "Projects" tab appears only for users with console access —
  admins, unrestricted users (`projects: null` / `["*"]`), or anyone granted at
  least one project. A video-only recipient (`projects: []`) never sees the tab.
  The decision is `Access.hasConsoleAccess(account)`.
- **Scoped content.** Inside the console, the dashboard stats, the projects grid,
  the recent-tasks list, and the "See All" task list are all filtered through
  `Access.canAccessProject`, so a scoped user (Dan) sees only their granted
  projects — not every project in `commander_tasks`. Admins/unrestricted see all.
- **Read view.** The console surfaces the project dashboard, task lists, task
  detail, workers, and progress — the read side of `manage.everbot.org/dan`. It is
  deliberately not a write console (see "What needs review").

## What needs review

- **Read-only was a deliberate scope choice.** `firestore.rules` gates task
  create/update/delete on `canAccessProject(...)`, which reads
  `commander_user_projects/{uid}` (uid-keyed) — a *different* collection from the
  `commander_allowed_users/{email}` (email-keyed) doc that both this app reads for
  scoping and the grant script writes. So a *write* console for Dan could be
  rejected server-side until a `commander_user_projects/{his-uid}` entry exists. I
  surfaced the console as read-only to avoid shipping buttons that fail. If Dan
  needs to create/retry tasks from the app, add that uid-keyed doc (a commander-repo
  step; the uid isn't known until he signs in once).
- **Verify the tab renders for a real granted user.** The gating *logic* is unit
  tested; confirm on device/emulator that signing in as `dan@palmr.ai` (after the
  grant is written to production) shows the Projects tab with the `dan` dashboard,
  and that a plain video user does not see the tab.
- **`commander_workers` reads.** The vendored `firestore.rules` in this repo has no
  `commander_workers` rule (default-deny in the emulator), so the Workers card may
  be empty under the emulator. Production rules (the source of truth in the
  commander repo) are expected to allow it; confirm there.
- **Tab label / placement.** I named it "Projects" (icon `square.grid.2x2`) and
  placed it between Chat and Videos. Change the copy/order if product prefers
  "Console" or a different slot.

## Action items (require a human)

- Run the grant against production so `dan@palmr.ai` gets the `dan` scope the app
  reads (needs Firebase Admin creds for `fir-web-codelab-8ace9`):
  ```
  GOOGLE_APPLICATION_CREDENTIALS=/path/to/sa.json \
    node scripts/grant-project-access.mjs dan@palmr.ai dan
  ```
  It prints before/after and is idempotent.
- Tell Dan to sign out/in on the Emma iOS app so `AuthService` re-reads his
  allowlist doc; the Projects tab then appears with the `dan` sandbox.
- Decide whether Dan also needs a `commander_user_projects/{uid}` entry for backend
  write enforcement (see "What needs review"). Commander-repo step, not this repo.
- Add a UITest for tab visibility (fake admin → tab present; fake non-admin →
  absent) once the Firebase Emulator Suite is available in CI.
- Push the `task/970-...` branch (the worker pushes automatically after the task).

## Files changed (this run)

- `Sources/Logic/Access.swift` — added `hasConsoleAccess(_:)`, the pure gating
  predicate for the console tab.
- `Sources/Views/ConsoleView.swift` — **new.** The "Projects" tab container; owns a
  `FirestoreService` and hosts the scoped `DashboardView`.
- `Sources/Views/RootTabView.swift` — added the gated "Projects" tab; reads
  `authService` to decide visibility via `Access.hasConsoleAccess`.
- `Sources/Views/Developer/DashboardView.swift` — scoped stats / projects / recent
  tasks to the signed-in user's granted projects (`scopedTasks`).
- `Sources/Views/Developer/TaskListView.swift` — scoped the task list the same way.
- `Tests/Unit/AccessTests.swift` — 4 new tests for `hasConsoleAccess`.
- `MobileCommander.xcodeproj/project.pbxproj` — regenerated via `xcodegen` to
  include `ConsoleView.swift`.
- `TEST_REPORT.md` — added the iOS build + unit-test results for this iteration.
