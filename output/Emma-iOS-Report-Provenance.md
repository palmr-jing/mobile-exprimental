# Emma iOS — Normalized app id + screen context on bug reports

**Task:** [reports] Emma iOS: stamp normalized app id + context on bug reports (mirror palmr-coach)
**Repo:** `mobile-exprimental` (native Emma iOS app, bundle `ai.palmr.emma`)
**Branch:** `task/1120-reports-emma-ios-stamp-normalized-app-id`
**Date:** 2026-07-24

## Why

The Emma iOS "Report an issue" sheet writes tickets **directly to `commander_tasks`**
(not the `issue_reports` inbox). Until now those tickets did not say which app or
screen they came from, only that they were `[iOS]` and named a tab in prose. That
makes reports easy to mis-attribute when several apps (palmr-coach, the web console,
Emma iOS) all file into the same shared fleet.

palmr-coach and the web `issue_reports` standard already stamp a normalized app id,
a platform, and a structured `context` object on every report. This change brings
Emma iOS to the same standard so **every report self-describes FROM which app/screen
it came and FOR which repo it's filed.**

## What changed

Every submission now writes three new fields onto the `commander_tasks` document, in
addition to the existing `project` / `path` (which still point at this repo):

| Field          | Value                    | Meaning                                        |
| -------------- | ------------------------ | ---------------------------------------------- |
| `app`          | `"emma-ios"`             | Normalized app id (the app the report is FROM) |
| `app_platform` | `"ios"`                  | Platform                                       |
| `context`      | a map, always `{ tab }`  | Where in the app, plus per-screen object detail |
| `project`      | `"mobile commander"`     | **Unchanged** — the fleet project              |
| `path`         | `"~/repos/mobile-exprimental"` | **Unchanged** — the repo the report is FOR |

### The `context` map

`context` always carries the `tab` the report came from. A screen that is focused on
a single object adds that object's identifying fields to the same map. The only such
screen today is the **recording viewer** (`AngleViewerView`), which stamps the class
recording being watched:

```jsonc
"context": {
  "tab": "Released",
  "screen": "recording",
  "className": "Muay Thai Kickboxing",
  "planId": "plan_42",              // Firestore doc id = plan_id
  "angleCount": 3,
  "anglesPresent": ["front", "front-right", "realsense"],
  "device": "everbot-lubancat-1",   // raw IMA rig id
  "room": "Studio A",
  "deviceLabel": "IMA (Ceiling) · Studio A",
  "date": "Jul 10, 2026 at 9:41 AM",
  "focusedAngle": "front-right"     // the angle open when Report was tapped
}
```

Absent optional fields (no device, no room, no start date, no angle in focus) are
**omitted**, not written as null. A tab with no single object in focus — Ask Emma,
Chat, Videos, the Released list — carries just `{ "tab": "..." }`.

## How it's wired

- `ReportContext` (value type) holds `tab` + a `[String: ReportContextValue]` screen
  map, and produces the Firestore `context` map via `firestoreValue`. `ReportContextValue`
  is a small typed enum (`string` / `int` / `strings`) so the builder is unit-testable
  without a live Firestore.
- `ReportContext.recording(_:focusedAngle:tab:)` builds the recording context from a
  `ReleasedRecording`.
- `ReportIssueButton(tab:context:)` gained an optional `context:`; tab-level buttons
  still pass just the tab.
- The recording viewer (`AngleViewerView`) got its own "Report an issue" toolbar
  button. It uses a **viewer-local** `ReportIssuePresenter` + a viewer-local report
  sheet rather than the app-root shared sheet: presenting the root sheet from inside an
  already-presented sheet asks UIKit to present from a controller that is now behind
  the viewer, which silently no-ops. A local sheet presents from the top controller as
  it must, and also avoids depending on an environment object that the mock UITest
  harness doesn't inject.

## Tests

Hermetic unit tests (`ReportIssueTests`) cover the context builder:

- `tabOnlyContextCarriesTheTab` — a plain tab maps to `{ tab }` only.
- `recordingContextCarriesTheClassIdentity` — the recording builder stamps class,
  plan id, angle count, angles present, device, room, focused angle, date.
- `recordingFirestoreValueFlattensAndOmitsAbsentFields` — values flatten to
  Firestore-safe scalars and absent optionals are omitted, not null.

One UITest (`ReleasedUITests.testViewerReportOpensTheReportSheet`) verifies the viewer's
report button opens the report sheet offline over the viewer. It stops short of
submitting because filing a ticket needs live Firestore.

All 130 unit tests and 15 `ReleasedUITests` pass on the iPhone 17 Pro simulator.

## Not done here

- **Actual submission is not asserted end-to-end** — `submit()` calls live Firestore
  (`addDocument`), which the offline simulator harness can't exercise. The payload
  shape is locked by the unit tests; the delivery path is unchanged from before.
- No TestFlight build was cut. This is a data-shape change; ship it on the next
  planned build bump after a full local suite run.
