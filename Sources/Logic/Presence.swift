import Foundation

// Swift port of commander/src/presence.js — the pure helpers for the team-chat
// roster, channel visibility, and @-mention autocomplete. No Firebase imports
// so this is trivially unit-testable, and it must stay behavior-compatible with
// the web (the unit tests mirror presence.js's vitest cases value-for-value).
enum Presence {
    // A user is online if their presence doc was touched within this window.
    static let presenceThresholdSeconds: TimeInterval = 60
    // Clients write a heartbeat this often while the app is foregrounded.
    static let heartbeatSeconds: TimeInterval = 25

    // Kept in sync with worker/emma.js + presence.js constants.
    static let emmaEmail = "emma@palmr.ai"
    static let emmaName = "Emma"

    static func isOnline(_ lastSeen: Date?, now: Date, threshold: TimeInterval = presenceThresholdSeconds) -> Bool {
        guard let lastSeen else { return false }
        return now.timeIntervalSince(lastSeen) <= threshold
    }

    // Merge the allowlist with live presence docs, keyed by lowercased email,
    // into a sorted roster: online first, then by name. Emma is appended as a
    // synthetic always-online member.
    static func buildRoster(
        allowedUsers: [AllowedUser],
        presenceDocs: [PresenceDoc],
        now: Date,
        selfEmail: String?,
        threshold: TimeInterval = presenceThresholdSeconds
    ) -> [RosterMember] {
        var presenceByEmail: [String: PresenceDoc] = [:]
        for p in presenceDocs where !p.email.isEmpty {
            presenceByEmail[p.email.lowercased()] = p
        }
        let me = (selfEmail ?? "").lowercased()

        var roster: [RosterMember] = allowedUsers.map { u in
            let email = u.email.lowercased()
            let p = presenceByEmail[email]
            // An explicit online:false (set on sign-out) overrides freshness.
            let online = p != nil && p!.online != false && isOnline(p!.lastSeen, now: now, threshold: threshold)
            let name = (p?.displayName.isEmpty == false ? p?.displayName : nil)
                ?? (u.name.isEmpty ? email : u.name)
            return RosterMember(
                email: email,
                name: name,
                photoURL: p?.photoURL,
                online: online,
                isSelf: email == me,
                isBot: false
            )
        }

        let emma = emmaEmail.lowercased()
        if !roster.contains(where: { $0.email == emma }) {
            roster.append(RosterMember(
                email: emma, name: emmaName, photoURL: nil,
                online: true, isSelf: false, isBot: true
            ))
        }

        roster.sort { a, b in
            if a.online != b.online { return a.online }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        return roster
    }

    // A channel is visible if it's public or the user is a member.
    static func visibleChannels(_ channels: [Channel], email: String?) -> [Channel] {
        let e = (email ?? "").lowercased()
        return channels.filter { c in
            c.isPublic || c.members.contains { $0.lowercased() == e }
        }
    }

    // A member's mention handle: the email local-part, lowercased and sanitized.
    static func mentionHandle(email: String?) -> String {
        let lower = (email ?? "").lowercased()
        let local = lower.split(separator: "@", maxSplits: 1).first.map(String.init) ?? ""
        return local.filter { $0.isLowercaseAlnum || $0 == "." || $0 == "_" || $0 == "-" }
    }

    // Resolve people mentioned in a message to roster members. Matches "@handle"
    // or "@firstname" tokens after a boundary, excludes the sender and bots.
    static func parseMentions(_ text: String?, roster: [RosterMember], selfEmail: String?) -> [RosterMember] {
        guard let text, !text.isEmpty else { return [] }
        let me = (selfEmail ?? "").lowercased()
        var tokens = Set<String>()
        for match in regexMatches(#"(^|\s)@([a-z0-9][a-z0-9._-]*)"#, in: text, group: 2) {
            tokens.insert(match.lowercased())
        }
        if tokens.isEmpty { return [] }

        var out: [RosterMember] = []
        var seen = Set<String>()
        for member in roster {
            if member.isBot { continue }
            let email = member.email.lowercased()
            if email.isEmpty || email == me || seen.contains(email) { continue }
            let handle = mentionHandle(email: member.email)
            let first = member.name.split(whereSeparator: { $0 == " " }).first.map { String($0).lowercased() } ?? ""
            if tokens.contains(handle) || (!first.isEmpty && tokens.contains(first)) {
                seen.insert(email)
                out.append(member)
            }
        }
        return out
    }

    // The active "@" query the user is typing (caret defaults to end of text).
    // Returns "" when "@" was just typed, or nil when not inside a mention.
    static func activeMentionQuery(_ text: String?, caret: Int? = nil) -> String? {
        guard let text else { return nil }
        let prefix = slice(text, upTo: caret)
        let matches = regexMatches(#"(^|\s)@([a-z0-9._-]*)$"#, in: prefix, group: 2)
        return matches.first
    }

    // Roster entries (minus self) whose handle or name prefix-matches the query.
    // Bots are included so Emma is pickable.
    static func matchMentionQuery(_ roster: [RosterMember], query: String?, selfEmail: String?, limit: Int = 6) -> [RosterMember] {
        let q = (query ?? "").lowercased()
        let me = (selfEmail ?? "").lowercased()
        let filtered = roster.filter { mb in
            if mb.email.lowercased() == me { return false }
            if q.isEmpty { return true }
            let handle = mentionHandle(email: mb.email)
            let name = mb.name.lowercased()
            return handle.hasPrefix(q) || name.split(whereSeparator: { $0 == " " }).contains { $0.hasPrefix(q) }
        }
        return Array(filtered.prefix(limit))
    }

    // Replace the active "@query" before the caret with "@handle " and report the
    // new caret position.
    static func applyMention(_ text: String?, caret: Int?, handle: String) -> (text: String, caret: Int) {
        let full = text ?? ""
        let before = slice(full, upTo: caret)
        let after = String(full.dropFirst(before.count))
        let replaced = replaceFirst(#"(^|\s)@([a-z0-9._-]*)$"#, in: before, with: "$1@\(handle) ")
        return (replaced + after, replaced.count)
    }

    // Classify an uploaded file into a message type the renderer understands.
    static func mediaType(_ contentType: String?) -> MessageType {
        guard let contentType, !contentType.isEmpty else { return .file }
        if contentType.hasPrefix("image/") { return .image }
        if contentType.hasPrefix("video/") { return .video }
        return .file
    }

    // Match "@emma" as its own token (kept in sync with worker/emma.js).
    static func mentionsEmma(_ text: String?) -> Bool {
        !regexMatches(#"(^|\s)@emma\b"#, in: text ?? "", group: 0).isEmpty
    }

    // ── Reply-to-message (parity with web TeamChat #811) ──────────────────────

    // The quoted-preview text stored on a reply: the parent's text truncated to
    // 120 chars, or an emoji label for media. Mirrors the web startReply().
    static func replyPreview(type: MessageType, text: String?, attachmentName: String?) -> String {
        let body = text ?? ""
        if !body.isEmpty {
            return body.count > 120 ? String(body.prefix(120)) + "…" : body
        }
        switch type {
        case .image: return "📷 Photo"
        case .video: return "🎬 Video"
        case .file:
            let name = (attachmentName ?? "").isEmpty ? "File" : attachmentName!
            return "📎 \(name)"
        case .text: return ""
        }
    }

    // When replying to an Emma-authored message, prepend "@emma" so the assistant
    // listener fires — but only if the text doesn't already mention her, and never
    // for replies to a human. Mirrors the web sendText() auto-tag.
    static func replyAutoTag(_ text: String, replyingToBot: Bool) -> String {
        guard replyingToBot, !mentionsEmma(text) else { return text }
        return "@emma \(text)"
    }

    // ── Regex helpers (case-insensitive, like the JS /.../i flags) ────────────
    private static func slice(_ text: String, upTo caret: Int?) -> String {
        guard let caret, caret >= 0, caret < text.count else { return text }
        return String(text.prefix(caret))
    }

    private static func regexMatches(_ pattern: String, in text: String, group: Int) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = text as NSString
        let results = re.matches(in: text, range: NSRange(location: 0, length: ns.length))
        return results.compactMap { m in
            guard group < m.numberOfRanges else { return nil }
            let r = m.range(at: group)
            return r.location == NSNotFound ? nil : ns.substring(with: r)
        }
    }

    private static func replaceFirst(_ pattern: String, in text: String, with template: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return text }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return text }
        return re.stringByReplacingMatches(in: text, range: m.range, withTemplate: template)
    }
}

private extension Character {
    var isLowercaseAlnum: Bool {
        ("a"..."z").contains(self) || ("0"..."9").contains(self)
    }
}
