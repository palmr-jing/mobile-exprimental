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
    // Poster frame for video attachments (e.g. a reel shared from the Videos
    // tab). Present on the wire as `thumbnail_url`; nil for plain uploads. When
    // set, chat renders a still + play glyph instead of an inline player.
    var thumbnailUrl: String?
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

// A class recording shared into chat as ONE bundle: the class name plus every
// camera angle's playable URL/poster. Held on the message so the chat card can
// render all angles and @emma can fetch any of them. Mirrors the `recording`
// object on the message document.
struct RecordingBundle: Equatable {
    var className: String
    var angles: [Angle]

    struct Angle: Identifiable, Equatable {
        var camera: String
        var url: String
        var storagePath: String?
        var thumbnailUrl: String?
        var id: String { camera }
    }
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
    var recording: RecordingBundle? = nil
    var mentions: [String]
    var mentionsEmma: Bool
    var emmaStatus: String?
    var isBot: Bool
    var emmaThinking: Bool
    var replyTo: ReplyContext?
}
