import Foundation
import FirebaseFirestore
import Combine

// The iOS analogue of the web TeamChat data layer. Subscribes to the same
// Firestore collections (commander_allowed_users / commander_presence /
// commander_channels + the active channel's messages) and writes the exact same
// message/notification shapes, so Emma and the web client interoperate.
@MainActor
final class ChatService: ObservableObject {
    static let generalId = "general"

    @Published var allowedUsers: [AllowedUser] = []
    @Published var presenceDocs: [PresenceDoc] = []
    @Published var channels: [Channel] = []
    @Published var messages: [ChannelMessage] = []
    @Published var roster: [RosterMember] = []
    @Published var activeChannelId: String = generalId
    @Published var isUploading = false

    // The private 1:1 Ask-Emma conversation, kept separate from team chat:
    // its own per-user channel + message stream so it never touches the shared
    // active channel and is only ever seen by this user.
    @Published var emmaMessages: [ChannelMessage] = []

    private let db = Firestore.firestore()
    private lazy var storageService = StorageService()
    private var user: UserAccount?

    private var allowedListener: ListenerRegistration?
    private var presenceListener: ListenerRegistration?
    private var channelListener: ListenerRegistration?
    private var messageListener: ListenerRegistration?
    private var emmaMessageListener: ListenerRegistration?
    private var rosterTimer: Timer?

    var myEmail: String { (user?.email ?? "").lowercased() }
    var myHandle: String { Presence.mentionHandle(email: user?.email) }

    // Per-user private channel id for the Ask-Emma tab.
    var emmaChannelId: String { "emma-\(user?.uid ?? "anon")" }

    // Channels the user can see, with a synthetic #general always present.
    var visibleChannels: [Channel] {
        // Private Ask-Emma channels live only in the Ask Emma tab — never list
        // them in team chat.
        var visible = Presence.visibleChannels(channels, email: user?.email)
            .filter { !$0.id.hasPrefix("emma-") }
        if !visible.contains(where: { $0.id == Self.generalId }) {
            visible.insert(Channel(id: Self.generalId, name: "general", isPublic: true,
                                   members: [], createdBy: "", createdAt: nil, lastMessageAt: nil), at: 0)
        }
        return visible
    }

    // The channel actually in view: fall back to the first visible channel if the
    // selected one disappears.
    var effectiveChannelId: String {
        visibleChannels.contains(where: { $0.id == activeChannelId })
            ? activeChannelId
            : (visibleChannels.first?.id ?? Self.generalId)
    }

    var onlineCount: Int { roster.filter { $0.online }.count }

    func start(user: UserAccount) {
        self.user = user
        allowedListener = db.collection("commander_allowed_users").addSnapshotListener { [weak self] snap, _ in
            guard let docs = snap?.documents else { return }
            Task { @MainActor in
                self?.allowedUsers = docs.map { Self.parseAllowedUser($0) }
                self?.rebuildRoster()
            }
        }
        presenceListener = db.collection("commander_presence").addSnapshotListener { [weak self] snap, _ in
            guard let docs = snap?.documents else { return }
            Task { @MainActor in
                self?.presenceDocs = docs.compactMap { Self.parsePresence($0) }
                self?.rebuildRoster()
            }
        }
        channelListener = db.collection("commander_channels").addSnapshotListener { [weak self] snap, _ in
            guard let docs = snap?.documents else { return }
            Task { @MainActor in self?.channels = docs.map { Self.parseChannel($0) } }
        }
        subscribeMessages()
        subscribeEmma()
        // Tick so online/offline dots refresh without new writes.
        rosterTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.rebuildRoster() }
        }
    }

    func stop() {
        [allowedListener, presenceListener, channelListener, messageListener, emmaMessageListener].forEach { $0?.remove() }
        allowedListener = nil; presenceListener = nil; channelListener = nil; messageListener = nil
        emmaMessageListener = nil
        rosterTimer?.invalidate(); rosterTimer = nil
        allowedUsers = []; presenceDocs = []; channels = []; messages = []; roster = []; emmaMessages = []
        user = nil
    }

    // ── Ask Emma (private 1:1) ──────────────────────────────────────────────────

    private func subscribeEmma() {
        emmaMessageListener?.remove()
        emmaMessageListener = db.collection("commander_channels").document(emmaChannelId)
            .collection("messages").order(by: "createdAt")
            .addSnapshotListener { [weak self] snap, _ in
                guard let docs = snap?.documents else { return }
                Task { @MainActor in self?.emmaMessages = docs.map { Self.parseMessage($0) } }
            }
    }

    /// Send a message to the private Ask-Emma channel. Always addressed to @emma
    /// so the assistant replies in-thread; never posts to the shared team chat.
    func sendToEmma(_ raw: String) async {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let text = Presence.mentionsEmma(trimmed) ? trimmed : "@emma \(trimmed)"
        do {
            try await ensureEmmaChannel()
            try await db.collection("commander_channels").document(emmaChannelId)
                .collection("messages").addDocument(data: [
                    "type": "text",
                    "text": text,
                    "mentionsEmma": true,
                    "emmaStatus": "pending",
                    "authorUid": user?.uid ?? "",
                    "authorName": user?.displayName ?? user?.email ?? "",
                    "authorEmail": user?.email ?? "",
                    "createdAt": FieldValue.serverTimestamp(),
                ])
        } catch {
            // Best-effort; the input keeps the text on failure.
        }
    }

    /// Send an attachment (with optional text) to the private Ask-Emma channel.
    /// Uploads the file to Firebase Storage under the Emma channel path, then
    /// posts a single message carrying both the attachment and the text.
    func sendToEmmaWithAttachment(text: String, data: Data, fileName: String, contentType: String) async {
        isUploading = true
        defer { isUploading = false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let messageText: String
        if trimmed.isEmpty {
            messageText = "@emma"
        } else {
            messageText = Presence.mentionsEmma(trimmed) ? trimmed : "@emma \(trimmed)"
        }
        do {
            try await ensureEmmaChannel()
            let attachment = try await storageService.upload(
                data: data, fileName: fileName, contentType: contentType, channelId: emmaChannelId
            )
            try await db.collection("commander_channels").document(emmaChannelId)
                .collection("messages").addDocument(data: [
                    "type": Presence.mediaType(contentType).rawValue,
                    "text": messageText,
                    "mentionsEmma": true,
                    "emmaStatus": "pending",
                    "authorUid": user?.uid ?? "",
                    "authorName": user?.displayName ?? user?.email ?? "",
                    "authorEmail": user?.email ?? "",
                    "createdAt": FieldValue.serverTimestamp(),
                    "attachment": [
                        "url": attachment.url,
                        "name": attachment.name,
                        "contentType": attachment.contentType,
                        "size": attachment.size,
                        "storage_path": attachment.storagePath,
                    ],
                ])
        } catch {
            // Best-effort; the input keeps the text on failure.
        }
    }

    private func ensureEmmaChannel() async throws {
        try await db.collection("commander_channels").document(emmaChannelId).setData([
            "name": "Ask Emma",
            "isPublic": false,
            "members": [myEmail].filter { !$0.isEmpty },
            "createdBy": user?.email ?? "",
            "createdAt": FieldValue.serverTimestamp(),
            "lastMessageAt": FieldValue.serverTimestamp(),
        ], merge: true)
    }

    func setActiveChannel(_ id: String) {
        activeChannelId = id
        subscribeMessages()
    }

    private func subscribeMessages() {
        messageListener?.remove()
        let channelId = effectiveChannelId
        messageListener = db.collection("commander_channels").document(channelId)
            .collection("messages").order(by: "createdAt")
            .addSnapshotListener { [weak self] snap, _ in
                guard let docs = snap?.documents else { return }
                Task { @MainActor in self?.messages = docs.map { Self.parseMessage($0) } }
            }
    }

    private func rebuildRoster() {
        roster = Presence.buildRoster(
            allowedUsers: allowedUsers,
            presenceDocs: presenceDocs,
            now: Date(),
            selfEmail: user?.email
        )
    }

    // ── Sending ───────────────────────────────────────────────────────────────

    func sendText(_ raw: String) async {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        var payload: [String: Any] = ["type": "text", "text": text]

        // Flag @emma so the worker-side assistant picks it up.
        if Presence.mentionsEmma(text) {
            payload["mentionsEmma"] = true
            payload["emmaStatus"] = "pending"
        }
        // Resolve @person mentions and notify them.
        let mentioned = Presence.parseMentions(text, roster: roster, selfEmail: user?.email)
        if !mentioned.isEmpty { payload["mentions"] = mentioned.map { $0.email } }

        do {
            try await postMessage(payload)
            await notifyMentions(mentioned, text: text)
        } catch {
            // Best-effort; the composer keeps the text on failure (handled by caller).
        }
    }

    func attach(data: Data, fileName: String, contentType: String) async {
        isUploading = true
        defer { isUploading = false }
        let channelId = effectiveChannelId
        do {
            let attachment = try await storageService.upload(
                data: data, fileName: fileName, contentType: contentType, channelId: channelId
            )
            try await postMessage([
                "type": Presence.mediaType(contentType).rawValue,
                "text": "",
                "attachment": [
                    "url": attachment.url,
                    "name": attachment.name,
                    "contentType": attachment.contentType,
                    "size": attachment.size,
                    "storage_path": attachment.storagePath,
                ],
            ])
        } catch {
            // Upload failures are surfaced via isUploading clearing; no crash.
        }
    }

    func createChannel(name: String, memberEmails: [String]) async {
        let members = Array(Set(([user?.email.lowercased()] + memberEmails.map { $0.lowercased() }).compactMap { $0 }))
        do {
            let ref = try await db.collection("commander_channels").addDocument(data: [
                "name": name,
                "isPublic": false,
                "members": members,
                "createdBy": user?.email ?? "",
                "createdAt": FieldValue.serverTimestamp(),
                "lastMessageAt": FieldValue.serverTimestamp(),
            ])
            setActiveChannel(ref.documentID)
        } catch { /* surfaced by the absence of a new channel */ }
    }

    private func ensureChannel(_ channelId: String) async throws {
        if channels.contains(where: { $0.id == channelId }) { return }
        try await db.collection("commander_channels").document(channelId).setData([
            "name": channelId == Self.generalId ? "general" : channelId,
            "isPublic": channelId == Self.generalId,
            "members": [],
            "createdBy": user?.email ?? "",
            "createdAt": FieldValue.serverTimestamp(),
            "lastMessageAt": FieldValue.serverTimestamp(),
        ], merge: true)
    }

    private func postMessage(_ payload: [String: Any]) async throws {
        let channelId = effectiveChannelId
        try await ensureChannel(channelId)
        var data: [String: Any] = [
            "authorUid": user?.uid ?? "",
            "authorName": user?.displayName ?? user?.email ?? "",
            "authorEmail": user?.email ?? "",
            "createdAt": FieldValue.serverTimestamp(),
        ]
        data.merge(payload) { _, new in new }
        try await db.collection("commander_channels").document(channelId)
            .collection("messages").addDocument(data: data)
        try? await db.collection("commander_channels").document(channelId)
            .updateData(["lastMessageAt": FieldValue.serverTimestamp()])
    }

    // Notify each mentioned teammate (written client-side by the sender, exactly
    // like the web). Best-effort.
    private func notifyMentions(_ members: [RosterMember], text: String) async {
        guard !members.isEmpty else { return }
        let channelId = effectiveChannelId
        let channelName = visibleChannels.first(where: { $0.id == channelId })?.name ?? channelId
        let fromName = user?.displayName ?? user?.email ?? ""
        for member in members {
            try? await db.collection("commander_notifications").addDocument(data: [
                "type": "mention",
                "recipient_email": member.email,
                "from_email": user?.email ?? "",
                "from_name": fromName,
                "channel_id": channelId,
                "channel_name": channelName,
                "text": String(text.prefix(280)),
                "message": "\(fromName) mentioned you in #\(channelName)",
                "read": false,
                "created_at": FieldValue.serverTimestamp(),
            ])
        }
    }

    // ── Parsing ────────────────────────────────────────────────────────────────

    private static func parseAllowedUser(_ doc: QueryDocumentSnapshot) -> AllowedUser {
        let d = doc.data()
        return AllowedUser(
            id: doc.documentID,
            email: (d["email"] as? String ?? "").lowercased(),
            name: d["displayName"] as? String ?? d["name"] as? String ?? "",
            isAdmin: d["isAdmin"] as? Bool ?? false,
            projects: d["projects"] as? [String]
        )
    }

    private static func parsePresence(_ doc: QueryDocumentSnapshot) -> PresenceDoc? {
        let d = doc.data()
        guard let email = d["email"] as? String, !email.isEmpty else { return nil }
        return PresenceDoc(
            email: email,
            displayName: d["displayName"] as? String ?? "",
            photoURL: d["photoURL"] as? String,
            online: d["online"] as? Bool ?? true,
            lastSeen: (d["lastSeen"] as? Timestamp)?.dateValue()
        )
    }

    private static func parseChannel(_ doc: QueryDocumentSnapshot) -> Channel {
        let d = doc.data()
        return Channel(
            id: doc.documentID,
            name: d["name"] as? String ?? doc.documentID,
            isPublic: d["isPublic"] as? Bool ?? false,
            members: d["members"] as? [String] ?? [],
            createdBy: d["createdBy"] as? String ?? "",
            createdAt: (d["createdAt"] as? Timestamp)?.dateValue(),
            lastMessageAt: (d["lastMessageAt"] as? Timestamp)?.dateValue()
        )
    }

    private static func parseMessage(_ doc: QueryDocumentSnapshot) -> ChannelMessage {
        let d = doc.data()
        var attachment: Attachment?
        if let a = d["attachment"] as? [String: Any], let url = a["url"] as? String {
            attachment = Attachment(
                url: url,
                name: a["name"] as? String ?? "",
                contentType: a["contentType"] as? String ?? "application/octet-stream",
                size: a["size"] as? Int ?? 0,
                storagePath: a["storage_path"] as? String ?? ""
            )
        }
        return ChannelMessage(
            id: doc.documentID,
            type: MessageType(rawValue: d["type"] as? String ?? "text") ?? .text,
            text: d["text"] as? String ?? "",
            authorUid: d["authorUid"] as? String ?? "",
            authorName: d["authorName"] as? String ?? "",
            authorEmail: d["authorEmail"] as? String ?? "",
            createdAt: (d["createdAt"] as? Timestamp)?.dateValue(),
            attachment: attachment,
            mentions: d["mentions"] as? [String] ?? [],
            mentionsEmma: d["mentionsEmma"] as? Bool ?? false,
            emmaStatus: d["emmaStatus"] as? String,
            isBot: d["isBot"] as? Bool ?? false,
            emmaThinking: d["emmaThinking"] as? Bool ?? false
        )
    }
}
