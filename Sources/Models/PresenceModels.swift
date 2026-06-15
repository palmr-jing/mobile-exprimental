import Foundation

// A live presence heartbeat doc, commander_presence/{uid}.
struct PresenceDoc: Equatable {
    var email: String
    var displayName: String
    var photoURL: String?
    var online: Bool
    var lastSeen: Date?
}

// A merged roster entry (allowlist + presence). Built by Presence.buildRoster.
struct RosterMember: Identifiable, Equatable {
    var email: String          // lowercased; doubles as the stable id
    var name: String
    var photoURL: String?
    var online: Bool
    var isSelf: Bool
    var isBot: Bool

    var id: String { email }
}
