import Foundation
import UIKit
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications

// Registers for push and persists the FCM token to the user's presence doc so
// the backend can deliver mention pushes. NOTE: actual delivery (a function that
// reacts to commander_notifications and sends FCM) is a backend follow-up — this
// only handles the client registration side.
final class PushService: NSObject {
    static let shared = PushService()

    private let db = Firestore.firestore()
    private var uid: String?
    private var pendingToken: String?

    // Request notification authorization and register for remote notifications.
    func register(uid: String) {
        self.uid = uid
        // If a token already arrived before we knew the uid, flush it now.
        if let token = pendingToken { writeToken(token, uid: uid) }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // Called by AppDelegate's MessagingDelegate when FCM mints/refreshes a token.
    func updateToken(_ token: String) {
        if let uid { writeToken(token, uid: uid) }
        else { pendingToken = token }   // buffer until we know who's signed in
    }

    private func writeToken(_ token: String, uid: String) {
        db.collection("commander_presence").document(uid).setData([
            "fcmToken": token,
            "platform": "ios",
        ], merge: true)
        pendingToken = nil
    }
}
