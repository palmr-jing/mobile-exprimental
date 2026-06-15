import Testing
import Foundation
@testable import MobileCommander

// Mirrors commander/src/presence.js's vitest cases so the Swift port stays
// behavior-compatible with the web.
struct PresenceTests {
    let now = Date(timeIntervalSince1970: 1_000_000)

    private func user(_ email: String, name: String = "") -> AllowedUser {
        AllowedUser(id: email, email: email, name: name, isAdmin: false, projects: nil)
    }

    @Test func isOnlineWithinAndBeyondThreshold() {
        #expect(Presence.isOnline(now.addingTimeInterval(-10), now: now) == true)
        #expect(Presence.isOnline(now.addingTimeInterval(-120), now: now) == false)
        #expect(Presence.isOnline(nil, now: now) == false)
    }

    @Test func buildRosterSortsOnlineFirstThenName() {
        let allowed = [user("zoe@x.com", name: "Zoe"), user("amy@x.com", name: "Amy")]
        let presence = [
            PresenceDoc(email: "amy@x.com", displayName: "Amy", photoURL: nil, online: true, lastSeen: now.addingTimeInterval(-5)),
        ]
        let roster = Presence.buildRoster(allowedUsers: allowed, presenceDocs: presence, now: now, selfEmail: "amy@x.com")
        // Amy online → first; Emma online bot; Zoe offline last.
        #expect(roster.first?.email == "amy@x.com")
        #expect(roster.first?.isSelf == true)
        #expect(roster.last?.email == "zoe@x.com")
    }

    @Test func buildRosterAppendsAlwaysOnlineEmmaBot() {
        let roster = Presence.buildRoster(allowedUsers: [user("a@x.com", name: "A")], presenceDocs: [], now: now, selfEmail: nil)
        let emma = roster.first { $0.email == "emma@palmr.ai" }
        #expect(emma != nil)
        #expect(emma?.online == true)
        #expect(emma?.isBot == true)
    }

    @Test func explicitOfflineOverridesFreshness() {
        let presence = [PresenceDoc(email: "a@x.com", displayName: "A", photoURL: nil, online: false, lastSeen: now)]
        let roster = Presence.buildRoster(allowedUsers: [user("a@x.com", name: "A")], presenceDocs: presence, now: now, selfEmail: nil)
        #expect(roster.first { $0.email == "a@x.com" }?.online == false)
    }

    @Test func visibleChannelsPublicOrMember() {
        let channels = [
            Channel(id: "general", name: "general", isPublic: true, members: [], createdBy: "", createdAt: nil, lastMessageAt: nil),
            Channel(id: "secret", name: "secret", isPublic: false, members: ["me@x.com"], createdBy: "", createdAt: nil, lastMessageAt: nil),
            Channel(id: "other", name: "other", isPublic: false, members: ["you@x.com"], createdBy: "", createdAt: nil, lastMessageAt: nil),
        ]
        let visible = Presence.visibleChannels(channels, email: "me@x.com").map(\.id)
        #expect(visible == ["general", "secret"])
    }

    @Test func mentionHandleIsSanitizedLocalPart() {
        #expect(Presence.mentionHandle(email: "James.Cheng@Palmr.ai") == "james.cheng")
        #expect(Presence.mentionHandle(email: "emma@palmr.ai") == "emma")
    }

    @Test func parseMentionsMatchesHandleAndFirstNameExcludesSelfAndBots() {
        let roster = [
            RosterMember(email: "tim@x.com", name: "Tim Cook", photoURL: nil, online: true, isSelf: false, isBot: false),
            RosterMember(email: "me@x.com", name: "Me", photoURL: nil, online: true, isSelf: true, isBot: false),
            RosterMember(email: "emma@palmr.ai", name: "Emma", photoURL: nil, online: true, isSelf: false, isBot: true),
        ]
        let byHandle = Presence.parseMentions("hey @tim look", roster: roster, selfEmail: "me@x.com")
        #expect(byHandle.map(\.email) == ["tim@x.com"])
        let byFirst = Presence.parseMentions("@Tim and @me", roster: roster, selfEmail: "me@x.com")
        #expect(byFirst.map(\.email) == ["tim@x.com"])   // self excluded
        // Email-like tokens must not match.
        #expect(Presence.parseMentions("email a@b.com", roster: roster, selfEmail: "me@x.com").isEmpty)
    }

    @Test func activeMentionQueryReadsTrailingToken() {
        #expect(Presence.activeMentionQuery("hi @ti") == "ti")
        #expect(Presence.activeMentionQuery("hi @") == "")
        #expect(Presence.activeMentionQuery("no mention here") == nil)
    }

    @Test func matchMentionQueryPrefixMatchesIncludingBots() {
        let roster = [
            RosterMember(email: "tim@x.com", name: "Tim Cook", photoURL: nil, online: true, isSelf: false, isBot: false),
            RosterMember(email: "emma@palmr.ai", name: "Emma", photoURL: nil, online: true, isSelf: false, isBot: true),
        ]
        #expect(Presence.matchMentionQuery(roster, query: "em", selfEmail: "me@x.com").map(\.email) == ["emma@palmr.ai"])
        #expect(Presence.matchMentionQuery(roster, query: "cook", selfEmail: "me@x.com").map(\.email) == ["tim@x.com"])
    }

    @Test func applyMentionReplacesActiveToken() {
        let result = Presence.applyMention("hey @ti", caret: nil, handle: "tim")
        #expect(result.text == "hey @tim ")
    }

    @Test func mediaTypeClassifiesContentType() {
        #expect(Presence.mediaType("image/png") == .image)
        #expect(Presence.mediaType("video/mp4") == .video)
        #expect(Presence.mediaType("application/pdf") == .file)
        #expect(Presence.mediaType(nil) == .file)
    }

    @Test func mentionsEmmaMatchesTokenNotLookalikes() {
        #expect(Presence.mentionsEmma("@emma status") == true)
        #expect(Presence.mentionsEmma("hey @Emma") == true)
        #expect(Presence.mentionsEmma("email@emma.example") == false)
        #expect(Presence.mentionsEmma("emma is great") == false)
    }
}
