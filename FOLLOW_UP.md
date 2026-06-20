# Follow-Up: Task #757 — "Took too long" timeout investigation

**What was done**: Investigated the full request flow from iOS to Firestore to backend worker to Claude CLI to find where the "took too long" timeout lives and why it fires. Added an elapsed-time display to the iOS thinking indicator so users can see the request is still alive. Raised the backend timeout from 3 to 5 minutes and added graceful process shutdown to salvage partial output on timeout.

**What needs review**:
- Verify the elapsed timer in AskEmmaView: after 5s it shows "(Xs)", after 2 min it switches to "Still working… (M:SS)"
- Check that the `contentTransition(.numericText())` animation looks smooth on the seconds counter
- The backend changes are in `~/repos/experimental/commander/worker/` (different repo) — they need to be committed and deployed separately

**Action items**:
- Commit the backend changes in `~/repos/experimental/commander/worker/` — `emma-agent.js` (timeout 3→5 min, graceful kill) and `emma-listener.js` (better timeout message)
- Restart the commander workers after deploying the backend change
- Long-term: switch from shelling out to the Claude CLI to using the Anthropic SDK directly — this lets us cancel the API request on timeout instead of wasting the spend

**Files changed**:
- `Sources/Views/Chat/AskEmmaView.swift` — Added elapsed-time counter to the thinking indicator using `Timer.publish` + `.onReceive`
- `~/repos/experimental/commander/worker/emma-agent.js` — Raised `EMMA_TIMEOUT_MS` 180s→300s, added 3s graceful shutdown before SIGKILL
- `~/repos/experimental/commander/worker/emma-listener.js` — Updated timeout message with actionable advice

---

## Full investigation report

### Architecture (no Cloud Functions involved)

The request never goes through an HTTP endpoint or Cloud Function:

1. **iOS** writes a message to Firestore with `emmaStatus: "pending"` (`ChatService.swift:123`)
2. **Backend worker** (long-running Node.js) picks it up via `collectionGroup('messages').where('emmaStatus', '==', 'pending')` (`emma-listener.js:38`)
3. Worker claims the message, spawns `claude` CLI as a child process (`emma-agent.js:138`)
4. Worker waits up to the timeout, then writes the reply back to Firestore
5. **iOS** receives the update through its Firestore `addSnapshotListener`

### Where the timeout lives

Server-side only. `emma-agent.js:31`:
- `EMMA_TIMEOUT_MS = 300_000` (5 min, was 3 min)
- `EMMA_RESUME_TIMEOUT_MS = 60_000` (1 min for session resume)

There is zero client-side timeout. The iOS app listens to Firestore indefinitely.

### When this fires, was the backend actually processing?

Yes. The worker claimed the message, spawned Claude, and was waiting. The timeout fires because Claude didn't produce output in time — not because the request was lost.

### Does the process get killed mid-run (wasting Claude spend)?

Yes. Previously: `proc.kill()` sent SIGTERM and immediately resolved with `response: null`, throwing away any partial stdout. Now: SIGTERM is sent, then a 3s grace period allows Claude to flush output before SIGKILL. Still not ideal — the API call to Anthropic may have completed, billing us for tokens we discard.

### Was the timeout too aggressive?

The old 3-minute timeout was tight for complex fleet queries. Opus over a large task set with tool use can legitimately take 3-5 minutes. The `chat-listener.js` already has a 10-minute "heavy" path. Raising Emma to 5 minutes is more appropriate.
