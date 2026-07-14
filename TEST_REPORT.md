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
via `firebase-tools emulators:exec` (run in the prior pass, for the `sandbox`
target — the merge logic is identical, only the project-slug argument changed):

- Seeded `dan@palmr.ai` with `projects: ['palmr-ios']`.
- Run 1 → project added to the list, existing project kept.
- Run 2 → no-op ("already has …"), list unchanged.

Status: **PASS** — project granted, prior access preserved, idempotent, no dupes.

Not re-run this pass: `firebase-tools` is not installed in this environment
(`node_modules` absent), so the emulator E2E was not repeated for the `dan`
target. The only change since the passing run is the CLI's `<project>` argument
(`sandbox` → `dan`), which the unit tests above cover directly against `planGrant`.

### 3. Syntax / smoke checks
- `node --check` on both edited scripts — clean.
- CLI with no args prints usage and exits 1 (the Firebase Admin SDK is imported
  lazily, so that path needs no credentials or network).

### 4. iOS console feature — build + unit tests (this iteration)
Surfaced the Commander console (`manage.everbot.org/<project>`) inside the Emma
app as a gated, project-scoped "Projects" tab (see FOLLOW_UP.md). Verified on the
iPhone 17 Pro simulator:

```
xcodebuild test -project MobileCommander.xcodeproj -scheme MobileCommander \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:MobileCommanderTests
```

- **Full app target compiles** with the new `ConsoleView`, the `RootTabView`
  gating, and the `DashboardView` / `TaskListView` project scoping.
- **`MobileCommanderTests`: 56 tests in 8 suites — all passed.**
- New `AccessTests` cases for the tab-gating decision (`Access.hasConsoleAccess`),
  all passing:
  - `consoleAccessForGrantedScopedUser` — Dan (`projects: ["dan"]`) → sees console.
  - `consoleAccessDeniedForEmptyProjects` — video-only user (`projects: []`) → no tab.
  - `consoleAccessForAdminAndUnrestricted` — admin / `nil` / `["*"]` → sees console.
  - `consoleAccessDeniedWhenSignedOut` — `nil` account → no tab.

## Not run
- iOS UITests for the new tab: asserting the "Projects" tab is visible/hidden
  end-to-end needs the Firebase Emulator Suite (anonymous sign-in against the auth
  emulator) which isn't installed here. The gating *logic* is covered by the unit
  tests above; the wiring is a straight SwiftUI `if` that compiles clean. Adding a
  UITest (fake admin → tab present; fake non-admin → absent) is a follow-up.
- Production write of Dan's grant: requires Firebase Admin credentials for the live
  project `fir-web-codelab-8ace9` (see FOLLOW_UP.md). Verified against the emulator
  in an earlier pass instead.
