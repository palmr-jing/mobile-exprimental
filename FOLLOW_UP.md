# Follow-Up — Task #947: open chat at the latest message + page older ones in

**What was done**: The team Chat thread now opens pinned to the most recent message
instead of the oldest, loads only the newest page up front, and pages older messages
in when you scroll to the top. Already-loaded messages stay resident for the session
(the window only grows, never shrinks), and Firestore's on-disk cache serves them again
on relaunch. Previously the thread subscribed to the entire channel history unbounded
and relied on a flaky scroll-to-bottom.

**What needs review**:
- Open a channel with more than ~30 messages and confirm it lands on the newest message
  (bottom), not the oldest — no visible scroll animation from the top.
- Scroll to the very top and confirm a spinner appears briefly and an older batch loads,
  and that the view does NOT jump to the bottom when those older messages appear. Repeat
  to page back further; confirm the spinner stops once you reach the first message.
- Send a new message while scrolled to the bottom — confirm it appears and the view
  follows it down. This is the one case where auto-scroll-to-bottom is intended.
- Switch channels back and forth: confirm each channel opens at its own latest page and
  that a channel you'd already scrolled back in reopens at that same depth (per-channel
  window is cached for the session).
- Confirm the paging window and scroll behavior work identically in Ask Emma vs team Chat
  (Ask Emma uses its own listener and is unchanged — verify it still opens at the latest).
- Verify behavior with an empty channel ("No messages yet…") and with exactly one page of
  messages (no spinner should show, since there's nothing earlier).

**Action items**:
- Push the `task/947-...` branch to remote (the worker pushes automatically after the task).
- Run the app on a simulator/device against a real (or emulator-seeded) channel that has
  more than 30 messages to eyeball the scroll-anchor and load-earlier behavior — the unit
  tests cover the paging math but not the SwiftUI scroll behavior, which needs a human eye.
- Optional: if channels commonly have thousands of messages, consider a "jump to latest"
  button when the user has paged far back, and/or capping how far back paging can go.

**Files changed**:
- `Sources/Logic/ChatPagination.swift` — NEW. Pure, Firebase-free paging helpers:
  `pageSize`/`initialLimit`, `nextLimit(_:)`, `hasEarlier(receivedCount:requestedLimit:)`,
  and `orderedAscending(fromDescending:)` (reverse a newest-first snapshot to oldest-first,
  de-duped by id). Unit-tested.
- `Sources/Services/ChatService.swift` — the message listener now orders by `createdAt`
  DESCENDING with a bounded `limit` (reversed for display) instead of reading all messages
  ascending. Added `hasEarlierMessages`/`isLoadingEarlier` published state, a per-channel
  window cache (`channelLimits`), and `loadEarlierMessages()` which grows the window by a
  page and re-subscribes. Stale-snapshot and channel-switch state are reset so windows and
  affordances don't leak across channels.
- `Sources/Views/Chat/ChatView.swift` — added `.defaultScrollAnchor(.bottom)` so the thread
  opens at the latest message; a top spinner sentinel that calls `loadEarlierMessages()` as
  it scrolls into view; and changed the follow-to-bottom trigger from `messages.count` to
  `messages.last?.id` so paging older messages in no longer yanks the reader to the bottom.
- `Tests/Unit/ChatPaginationTests.swift` — NEW. 5 tests over the paging helpers.
- `TEST_REPORT.md`, `DEPLOY_STATUS.md` — updated for this task.
