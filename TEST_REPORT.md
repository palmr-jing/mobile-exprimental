# Test Report — Task #1038 (Emma: file a task instead of dropping a slow request)

## Build Status
- **Platform**: iOS Simulator — iPhone 17 Pro
- **Status**: BUILD SUCCEEDED + **TEST SUCCEEDED** (`xcodebuild test -scheme MobileCommander -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:MobileCommanderTests`)
- Full unit target: **73 tests / 10 suites, all green.**

## What changed and why it's testable
The Emma *worker* that posts "That took too long and I had to stop — try a narrower
question." lives on the backend, not in this repo. This iOS app is a Firestore
client, so the fix is client-side recovery: when Emma posts that dead-end reply,
the bubble offers a one-tap "Turn this into a task" that files the dropped request
as a `commander_tasks` ticket and shows the returned number. The recognition,
request-lookup, and ticket-shaping logic is pure (`EmmaEscalation`) so it's unit
tested; the Firestore write (`ChatService.fileDroppedEmmaTask`) is exercised by the
build compiling every call site.

## Tests

### Unit Tests (`Tests/Unit/EmmaEscalationTests.swift` — NEW, 9 cases)
- `recognisesTheWorkerTimeoutReply` / `ignoresNormalReplies` — the "took too long / had to stop" reply is detected (case-insensitive), normal replies and empty/nil are not.
- `precedingRequestPrefersTheAtEmmaAsk` — in a busy channel, the dropped request is the nearest earlier `@emma` message, not just the previous line.
- `precedingRequestFallsBackToNearestHuman` — with no `@emma` tag, falls back to the nearest earlier human message.
- `precedingRequestSkipsBotsAndMissingIds` — bot-only threads and unknown ids return nil (no crash).
- `docIdIsDeterministicPerMessage` — `emma-timeout-<messageId>`, the idempotency key.
- `titleStripsMentionPrefixesAndClips` — `[Emma] …` title, `@emma` stripped, 80-char clip, empty-request fallback.
- `bodyCarriesRequestAndOrigin` — body includes the original request + origin (`#channel` or "Ask Emma"), with the `@emma` mention stripped.

Other suites (AccessTests, ChatPaginationTests, ChatShareTests, PresenceTests,
VideoTests, ReelExportTests, ReportIssueTests, ReleasedRecordingTests,
SpeechRecognitionServiceTests) — unchanged, still pass.

## How to Run
```bash
# Unit tests only (hermetic, no emulator):
SKIP_EMULATOR=1 scripts/run-tests.sh

# Just the new suite:
xcodebuild test -scheme MobileCommander \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:MobileCommanderTests/EmmaEscalationTests
```

## Not covered here
- **No UI test** for the button/filed states yet — driving it needs the emulator
  seeded with an Emma timeout reply. The affordance has accessibility ids
  (`emma-file-task`, `emma-filed-task`, `emma-file-task-retry`) so a UITest can be
  added. Flagged in FOLLOW_UP.
- **Live Firestore write** (`fileDroppedEmmaTask`) not exercised against a real
  backend — needs interactive Google sign-in this autonomous run can't do. It
  reuses the same `commander_tasks` create shape + access rule as the shipping
  "Report an issue" flow.
