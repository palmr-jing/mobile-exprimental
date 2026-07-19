# Deploy status — #1075

**Target:** TestFlight (App Store Connect app id `6780673334`, bundle `ai.palmr.emma`).

**Deployed: no. Deliberately not uploaded.**

## Build status

Debug build for the iOS Simulator: **succeeds**. Full test suite passes (99 unit
tests + 16 UI cases, 0 failures) — see `TEST_REPORT.md`. A Release archive was not
produced.

## Why no upload

1. **The build number was not bumped.** `CURRENT_PROJECT_VERSION` in `project.yml` is
   still `20260719.1`, which was already used by the last upload (commit `4cc3cb2`).
   Re-uploading it would be rejected.
2. **Uploading was not part of this task**, and it burns a build number plus an
   Apple processing round-trip.
3. **A sibling worker is doing overlapping work.** The worktree
   `.worktrees/task-1072` is on `task/1072-ios-released-videos-need-the-palmr-logo`
   — same Released-tab watermark surface. Shipping this branch alone risks a build
   that conflicts with, or half-duplicates, that one. These two should be merged and
   reconciled before a TestFlight build goes out.

## To ship this

```sh
# 1. Reconcile with task/1072 first (see FOLLOW_UP.md).
# 2. Bump CURRENT_PROJECT_VERSION in project.yml to a fresh YYYYMMDD.N, commit to main.
# 3. Re-run the suite locally (required by CLAUDE.md), then:
ASC_ISSUER_ID=<uuid> scripts/upload-testflight.sh
```

Non-applicable: there is no web/Firebase Hosting component in this change. No
Firestore or Storage rules were touched.
