# Follow-Up — Task #835: reply-to-message + auto-tag @emma (iOS Chat)

**What was done**: Added reply-to-message to the team Chat view on iOS, matching the
web TeamChat feature from commander #811. You can now reply to any message (long-press
menu or swipe right), see the quoted parent inside reply bubbles, tap a quote to jump to
the original, and a reply bar above the composer shows what you're replying to. Replying
to an Emma message auto-prepends `@emma` so the assistant fires; replying to a teammate
does not. The persisted `replyTo` shape matches the web exactly, so threads stay in sync
across web and iOS.

**What needs review**:
- Reply to an Emma (BOT) message and send — confirm the text goes out with `@emma`
  prepended and Emma actually responds. Then reply to a human message and confirm `@emma`
  is NOT added.
- Confirm the persisted Firestore field is `replyTo: { id, text, authorName, authorUid }`
  (4 fields, no `isBot`) and that a reply created on iOS renders correctly in the web app,
  and vice-versa.
- Tap a quoted parent inside a reply bubble — it should scroll to and briefly ring the
  original message. If the parent is too old to be loaded, nothing should happen (no crash).
- Switch channels while a reply is staged — the reply bar should clear (the draft must not
  leak into another channel).
- Swipe-to-reply: confirm a right-swipe on a bubble starts a reply and that it doesn't
  interfere with normal vertical scrolling. Confirm swipe/long-press do nothing in Ask Emma
  (reply is Chat-only by design).
- The reply preview truncates long text at 120 chars and shows 📷/🎬/📎 labels for media.

**Action items**:
- Push the `task/835-...` branch to remote (the worker pushes automatically after the task).
- Run the UI test under the emulator to exercise the end-to-end path:
  `scripts/run-tests.sh` (it runs `testReplyBarAppearsAndCancels`).
- Optional: consider also carrying `replyTo` on attachment sends. Right now (matching web)
  replies attach to the text message only; an image-only reply won't carry the quote.

**Files changed**:
- `Sources/Models/Channel.swift` — added `ReplyContext` struct (the 4-field persisted shape)
  and a `replyTo: ReplyContext?` field on `ChannelMessage`.
- `Sources/Logic/Presence.swift` — added pure helpers `replyPreview(type:text:attachmentName:)`
  and `replyAutoTag(_:replyingToBot:)`, both unit-tested.
- `Sources/Services/ChatService.swift` — added `replyDraft` state + `ReplyDraft` type, a
  `focusComposerToken`, `startReply(to:)`/`cancelReply()`; `sendText` now auto-tags, writes
  the `replyTo` map, and clears/restores the draft; `parseMessage` reads `replyTo`; draft is
  cleared on channel switch and sign-out.
- `Sources/Views/Chat/MessageBubbleView.swift` — quoted-parent block (tap to scroll),
  long-press context menu + swipe-to-reply gesture, and a highlight ring. Reply hooks are
  optional so Ask Emma is unaffected.
- `Sources/Views/Chat/ChatView.swift` — wires reply + scroll-to-parent through the existing
  `ScrollViewReader`, with a brief highlight on the target message.
- `Sources/Views/Chat/ChatComposerView.swift` — reply bar above the composer ("Replying to
  {name}" + preview + cancel), and auto-focus when a reply starts.
- `Tests/Unit/PresenceTests.swift` — 3 new tests for the reply helpers.
- `Tests/UITests/ChatUITests.swift` — new `testReplyBarAppearsAndCancels`.
- `TEST_REPORT.md`, `DEPLOY_STATUS.md` — updated for this task.
