import Foundation
import FirebaseFirestore

// Listens for the current user's unread notifications (mentions + fleet alerts)
// and drives the in-app bell. Mirrors the web NotificationBell read path.
@MainActor
final class NotificationService: ObservableObject {
    @Published var notifications: [AppNotification] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var email: String = ""

    var unreadCount: Int { notifications.filter { !$0.read }.count }

    func start(email: String) {
        self.email = email.lowercased()
        listener?.remove()
        // Unread, newest first. We filter by recipient client-side (a nil
        // recipient is a broadcast) to avoid a composite index, matching the web.
        listener = db.collection("commander_notifications")
            .whereField("read", isEqualTo: false)
            .order(by: "created_at", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let docs = snap?.documents else { return }
                Task { @MainActor in
                    self.notifications = docs.compactMap { Self.parse($0) }
                        .filter { $0.recipientEmail == nil || $0.recipientEmail?.lowercased() == self.email }
                }
            }
    }

    func stop() {
        listener?.remove(); listener = nil
        notifications = []
    }

    func markRead(_ id: String) {
        db.collection("commander_notifications").document(id).updateData(["read": true])
    }

    func markAllRead() {
        for n in notifications { markRead(n.id) }
    }

    private static func parse(_ doc: QueryDocumentSnapshot) -> AppNotification? {
        let d = doc.data()
        return AppNotification(
            id: doc.documentID,
            type: d["type"] as? String ?? "mention",
            recipientEmail: d["recipient_email"] as? String,
            fromName: d["from_name"] as? String ?? "",
            channelId: d["channel_id"] as? String,
            channelName: d["channel_name"] as? String,
            text: d["text"] as? String ?? "",
            message: d["message"] as? String ?? "",
            read: d["read"] as? Bool ?? false,
            createdAt: (d["created_at"] as? Timestamp)?.dateValue()
        )
    }
}
