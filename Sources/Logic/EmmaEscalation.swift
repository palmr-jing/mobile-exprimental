import Foundation

// When Emma takes too long on a request she stops and posts a dead-end reply
// ("That took too long and I had to stop — try a narrower question.") from the
// worker, dropping the work. This turns that dead end into a tracked task: pure,
// unit-testable helpers for recognising the reply, finding the request it was
// dropped on, and shaping the commander_tasks document. The actual Firestore
// write lives in ChatService.fileDroppedEmmaTask.
//
// The write is keyed by the timeout message id (see taskDocId) so filing is
// idempotent — a double-tap, or two devices watching the same thread, collapse
// to ONE ticket rather than spraying duplicates.
enum EmmaEscalation {
    // Recognise the worker's "gave up because it took too long" reply. Matched
    // loosely (either half of the phrase) so a small copy tweak on the worker
    // side doesn't silently disable the affordance. Callers only apply this to
    // bot-authored messages, so a human quoting the phrase won't trigger it.
    static func isTimeoutReply(_ text: String?) -> Bool {
        guard let t = text?.lowercased() else { return false }
        return t.contains("took too long") || t.contains("had to stop")
    }

    // The request Emma dropped: walking back from the timeout reply, prefer the
    // nearest earlier @emma message (the actual ask in a busy channel), else the
    // nearest earlier human message. Bot messages are skipped.
    static func precedingRequest(before messageId: String, in messages: [ChannelMessage]) -> ChannelMessage? {
        guard let idx = messages.firstIndex(where: { $0.id == messageId }) else { return nil }
        var fallback: ChannelMessage?
        for i in stride(from: idx - 1, through: 0, by: -1) {
            let m = messages[i]
            let isBot = m.isBot || m.authorUid == "emma-bot"
            if isBot { continue }
            if m.mentionsEmma { return m }
            if fallback == nil { fallback = m }
        }
        return fallback
    }

    // Deterministic doc id → filing the same dropped request twice is a no-op.
    static func taskDocId(timeoutMessageId: String) -> String {
        "emma-timeout-\(timeoutMessageId)"
    }

    // "[Emma] <first line of the request>", clipped — mirrors the ReportIssue
    // title shape so triage can spot Emma-dropped work at a glance.
    static func taskTitle(request: String) -> String {
        let cleaned = stripEmmaMention(request).trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = cleaned.split(separator: "\n").first.map(String.init) ?? ""
        let base = firstLine.isEmpty ? "Emma request that timed out" : firstLine
        let clipped = base.count > 80 ? String(base.prefix(80)) + "…" : base
        return "[Emma] \(clipped)"
    }

    // Body that carries the original ask plus where it came from, and says plainly
    // that Emma stopped short so a worker should run it and report back.
    static func taskBody(request: String, channelName: String?) -> String {
        let cleaned = stripEmmaMention(request).trimmingCharacters(in: .whitespacesAndNewlines)
        let origin = channelName.map { "#\($0)" } ?? "the private Ask Emma thread"
        return """
        Filed from the Emma iOS app because Emma took too long and stopped before \
        finishing this request (from \(origin)).

        Original request:
        \(cleaned.isEmpty ? "(no text — see the chat thread)" : cleaned)

        Emma dropped this instead of answering inline. Pick the right project, run \
        it as a task, and report back in the thread.
        """
    }

    // Strip a leading "@emma" so it doesn't lead the task title/body.
    static func stripEmmaMention(_ text: String) -> String {
        guard let re = try? NSRegularExpression(pattern: #"^\s*@emma\b\s*"#, options: [.caseInsensitive]) else {
            return text
        }
        let ns = text as NSString
        return re.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: ns.length), withTemplate: "")
    }
}
