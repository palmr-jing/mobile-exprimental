# Follow-Up

**What was done**: Fixed stale relative timestamps in chat messages. Wrapped the timestamp display in a `TimelineView` that re-evaluates every 30 seconds, and made `relativeTime()` handle nil dates (Firestore pending writes) by defaulting to "now".

**What needs review**:
- Open the Ask Emma tab, send a message, and wait 2+ minutes — verify the timestamp updates from "now" to "1m", "2m", etc.
- Check that the team chat (ChatView) timestamps also update correctly since it shares `MessageBubbleView`.
- Verify that messages older than 24 hours still show a short date (e.g., "6/19/26") instead of relative time.

**Action items**:
- None — changes are self-contained. Push to remote when ready for review.

**Files changed**:
- `Sources/Views/Chat/MessageBubbleView.swift` — Wrapped timestamp in `TimelineView(.periodic(from: .now, by: 30))` for auto-refresh; changed `relativeTime(_:)` to accept `Date?` and return "now" for nil.
