import Foundation
import SwiftUI
import FirebaseFirestore

// Writes our own commander_presence/{uid} heartbeat so other clients see us
// online. Firestore has no onDisconnect, so we rely on a freshness window plus a
// best-effort offline write when the app backgrounds or signs out. Mirrors the
// web usePresenceHeartbeat.
@MainActor
final class PresenceService: ObservableObject {
    private let db = Firestore.firestore()
    private var user: UserAccount?
    private var timer: Timer?

    func start(user: UserAccount) {
        self.user = user
        beat(online: true)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Presence.heartbeatSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.beat(online: true) }
        }
    }

    func stop() {
        timer?.invalidate(); timer = nil
        beat(online: false)
        user = nil
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        guard user != nil else { return }
        switch phase {
        case .active: beat(online: true)
        case .background, .inactive: beat(online: false)
        @unknown default: break
        }
    }

    private func beat(online: Bool) {
        guard let user, !user.uid.isEmpty else { return }
        db.collection("commander_presence").document(user.uid).setData([
            "email": user.email,
            "displayName": user.displayName,
            "photoURL": user.photoURL as Any,
            "online": online,
            "lastSeen": FieldValue.serverTimestamp(),
        ], merge: true)
    }
}
