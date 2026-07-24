# Follow-up — stamp app id + screen context on Emma iOS reports

**What was done**: The "Report an issue" flow now stamps `app: "emma-ios"`,
`app_platform: "ios"`, and a structured `context` map on every `commander_tasks`
document, matching palmr-coach and the web `issue_reports` standard so reports
self-describe which app/screen they came from. `project`/`path` still point at
`mobile-exprimental`. The recording viewer stamps the exact class it's showing
(className, planId, device/room, date, angles, focused angle).

**What needs review**:
- Confirm the field names match palmr-coach exactly. I mirrored the task spec:
  `app`=`emma-ios`, `app_platform`=`ios`, `context.tab`, and recording keys
  `className / planId / angleCount / anglesPresent / device / room / deviceLabel /
  date / focusedAngle`. If palmr-coach uses different key spellings (e.g. `plan_id`
  vs `planId`, or nests recording fields under a `screen` object), align them —
  they're all built in `ReportContext.recording(...)` in `Sources/Views/Support/ReportIssue.swift`.
- Decide whether the non-recording tabs (Ask Emma, Chat, Videos) should carry more
  than `{ tab }`. Today they carry only the tab because no single object is in focus.
- Verify a real report on-device actually writes the new fields (I could not assert
  the Firestore write on the simulator — see below).

**Action items** (human-only):
- Do a live smoke test: file a report from the recording viewer on a TestFlight/dev
  build and confirm the `commander_tasks` doc has `app`, `app_platform`, and a
  populated `context` map with the recording fields.
- When ready to ship: bump `CURRENT_PROJECT_VERSION` in `project.yml`, run the full
  suite, then `scripts/upload-testflight.sh`. Not done here on purpose.
- Push the branch (the worker pushes commits automatically).

**Files changed**:
- `Sources/Views/Support/ReportIssue.swift` — added `ReportContext` + `ReportContextValue`
  types; `submit(...)` now takes a `ReportContext` and writes `app`/`app_platform`/`context`;
  `Draft` carries the context; `start(context:)` added (with a `start(tab:)` convenience);
  `ReportIssueButton` gained an optional `context:`.
- `Sources/Views/Recordings/AngleViewerView.swift` — added a `recording:` parameter, a
  viewer-local `ReportIssuePresenter`, a "Report an issue" toolbar button, and a
  viewer-local report sheet.
- `Sources/Views/Recordings/ReleasedRecordingsView.swift` — `OpenAngle` now carries the
  parent `ReleasedRecording`, passed into `AngleViewerView`.
- `Tests/Unit/ReportIssueTests.swift` — 3 new tests for the context builder.
- `Tests/UITests/ReleasedUITests.swift` — 1 new test: the viewer's report button opens
  the report sheet offline.
- `output/Emma-iOS-Report-Provenance.md` — the deliverable write-up.
- `TEST_REPORT.md`, `DEPLOY_STATUS.md` — status notes.

**Note on what isn't tested**: `submit(...)` writes to live Firestore, so the actual
new-field write isn't asserted on the simulator. The payload *shape* is locked by the
unit tests; the delivery path is unchanged. That's the one gap to close with the live
smoke test above.
