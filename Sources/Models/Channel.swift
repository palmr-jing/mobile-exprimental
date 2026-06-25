import Foundation

// A team-chat channel. Mirrors a commander_channels/{id} document.
struct Channel: Identifiable, Equatable {
    let id: String
    var name: String
    var isPublic: Bool
    var members: [String]
    var createdBy: String
    var createdAt: Date?
    var lastMessageAt: Date?
}

// The kind of payload a message carries. Matches the web `type` field and the
// strings produced by Presence.mediaType().
enum MessageType: String {
    case text
    case image
    case video
    case file
}

// An uploaded attachment stored in Firebase Storage. Mirrors the web's
// `attachment` object (note the snake_case storage_path on the wire).
struct Attachment: Equatable {
    var url: String
    var name: String
    var contentType: String
    var size: Int
    var storagePath: String
}

// The quoted parent a reply points at. Mirrors the web TeamChat `replyTo` object
// persisted on the message document: exactly these four fields (the client-only
// `isBot` flag used to decide @emma auto-tagging is NOT part of the wire shape).
struct ReplyContext: Equatable {
    var id: String
    var text: String
    var authorName: String
    var authorUid: String
}

// A single message in a channel. Distinct from the per-task ChatMessage (which
// lives in commander_tasks/{id}/chat) — this mirrors
// commander_channels/{id}/messages/{id}.
struct ChannelMessage: Identifiable, Equatable {
    let id: String
    var type: MessageType
    var text: String
    var authorUid: String
    var authorName: String
    var authorEmail: String
    var createdAt: Date?
    var attachment: Attachment?
    var mentions: [String]
    var mentionsEmma: Bool
    var emmaStatus: String?
    var isBot: Bool
    var emmaThinking: Bool
    var replyTo: ReplyContext?
}
