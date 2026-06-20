# Follow-Up

**What was done**: Fixed the Ask Emma chat so it opens scrolled to the latest message (bottom) instead of the oldest (top), and auto-scrolls to the "thinking" spinner when a new message is sent.

**What needs review**:
- Open the Ask Emma tab with an existing conversation history — verify it starts at the bottom showing the most recent messages
- Send a message and confirm the view scrolls down to show the "Emma is thinking…" spinner
- Receive Emma's reply and confirm the view scrolls to show her response
- Scroll up manually to read old messages — confirm the view does NOT yank you back to the bottom unless a new message arrives

**Action items**:
- Test on a real device or simulator with a conversation that has enough messages to require scrolling
- Push to remote when satisfied

**Files changed**:
- `Sources/Views/Chat/AskEmmaView.swift` — Added `.defaultScrollAnchor(.bottom)` to the ScrollView so it opens at the bottom; updated `onChange` handler to scroll to the "thinking" indicator when visible
