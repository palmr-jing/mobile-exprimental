# Follow-up — Task #1038

**What was done**: When Emma stops on a request because it took too long ("That took
too long and I had to stop — try a narrower question."), the chat bubble now offers a
one-tap "Turn this into a task" that files the dropped request as a `commander_tasks`
ticket and shows the returned number ("Filed #N — tracking it there"), so the request
is tracked instead of lost. Works in both team Chat and the private Ask Emma thread.

## Important context
The Emma bot that actually times out and posts the dead-end reply runs on the
**backend/worker, which is not in this iOS repo** — this app is a Firestore client.
So the truly automatic behavior the task describes ("*Emma* files a task before
dropping it") belongs in the Emma worker, out of reach here. What shipped is the
iOS-side recovery: a human sees the dead end and turns it into a tracked ticket in
one tap. Filing is idempotent (keyed by the timeout message id), so a double-tap —
or two people/devices on the same team channel — collapse to ONE ticket rather than
spraying duplicates. That idempotency is also why it isn't auto-fired on every
client: auto-filing across N viewers, plus back-filling every historical timeout on
load, would create noise; a deliberate tap avoids both.

## What needs review
- **Decision: is a one-tap button enough, or do you want it fully automatic?** If
  automatic is required, that's a change in the Emma worker (file the task + return
  the number in Emma's own reply). This iOS change is compatible with that — it's a
  safety net either way.
- **Task routing**: an Emma-dropped request isn't necessarily iOS/mobile-commander
  work (e.g. "reduce memory usage on manage.everbot.org"). The ticket is filed into
  the `mobile commander` project (same convention as "Report an issue"), left
  UNassigned (auto worker, not the iOS builder), with a body that says "pick the
  right project and re-route." Confirm that triage lane is where you want these to
  land, or tell me a better default project/inbox.
- **Copy**: check the button + confirmation strings in
  `Sources/Views/Chat/MessageBubbleView.swift` (`escalationRow`) and the ticket
  title/body in `Sources/Logic/EmmaEscalation.swift`.
- **Detection string**: `EmmaEscalation.isTimeoutReply` matches "took too long" /
  "had to stop". If the worker changes that copy, update this matcher (kept
  intentionally loose so a small tweak doesn't silently disable the button).

## Action items
- Push the branch (worker auto-pushes) and build a TestFlight if you want it on device.
- Human-only: decide the routing default (above) and whether to make it automatic in
  the Emma worker.
- Optional: add a UITest driving `emma-file-task` → `emma-filed-task` under the
  Firebase emulator (seed a message whose text is the timeout reply). Accessibility
  ids are already in place.

## Files changed
- `Sources/Logic/EmmaEscalation.swift` — NEW. Pure helpers: detect the timeout
  reply, find the dropped request in the thread, deterministic idempotency doc id,
  and the ticket title/body shape.
- `Sources/Services/ChatService.swift` — NEW `fileDroppedEmmaTask(...)` (idempotent
  `commander_tasks` write, returns the ticket num_id) + `nextTaskNumId()` helper.
- `Sources/Views/Chat/MessageBubbleView.swift` — `onFileTask` hook + `escalationRow`
  (idle → filing → filed #N → retry) shown only on Emma timeout replies.
- `Sources/Views/Chat/ChatView.swift` — passes `onFileTask` (resolves the dropped
  request from the team thread + channel name).
- `Sources/Views/Chat/AskEmmaView.swift` — passes `onFileTask` for the private thread.
- `Tests/Unit/EmmaEscalationTests.swift` — NEW, 9 cases over the pure logic.
- `TEST_REPORT.md`, `DEPLOY_STATUS.md` — updated for this task.
