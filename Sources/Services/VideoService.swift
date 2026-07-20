import Foundation
import FirebaseFirestore
import FirebaseStorage
import Combine

// Live feed of the videos released to the signed-in user. Backed by the
// `commander_videos` collection that manage.everbot.org's Reels "Release to app"
// action writes to; each doc carries an `assigned_emails` array, so we scope by
// the user's own email (the identity they authenticated with).
//
// We filter with a single `arrayContains` and sort client-side rather than
// adding an `.order(by:)` — combining the two would require a composite index,
// and each user's assigned set is small.
@MainActor
final class VideoService: ObservableObject {
    @Published var videos: [AssignedVideo] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var currentEmail: String?

    // Begin (or restart) the subscription for the given user email.
    func start(email: String) {
        let normalized = email.lowercased()
        guard normalized != currentEmail else { return }  // already listening
        stop()
        currentEmail = normalized

        // An empty email (anonymous / emailless sign-in) can't own an assignment.
        guard !normalized.isEmpty else {
            videos = []
            isLoading = false
            return
        }

        isLoading = true
        listener = db.collection("commander_videos")
            .whereField("assigned_emails", arrayContains: normalized)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false
                    if let error {
                        self.errorMessage = Self.friendlyMessage(for: error)
                        return
                    }
                    self.errorMessage = nil
                    let parsed = (snapshot?.documents ?? [])
                        .compactMap { AssignedVideo.from(id: $0.documentID, data: $0.data()) }
                    self.videos = AssignedVideo.sortedNewestFirst(parsed)
                }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
        currentEmail = nil
    }

    // Re-subscribe after a failure. Firestore TERMINATES a snapshot listener on
    // permission-denied and never retries it, and `start` early-returns when the
    // email is unchanged — so without this the tab stays stuck on the error for
    // the rest of the session even once the backend is healthy again. That is
    // what #1069 looked like from the user's side: the Firestore rules for
    // `commander_videos` were dropped by an unrelated deploy, and force-quitting
    // the app was the only way back.
    func retry() {
        guard let email = currentEmail else { return }
        stop()  // clears currentEmail, so the "already listening" guard won't block
        errorMessage = nil
        start(email: email)
    }

    // Firestore's own `localizedDescription` for a rules denial is "Missing or
    // insufficient permissions." — accurate but it reads as the user's fault and
    // offers no way forward. Access to videos is granted server-side, so the
    // honest framing is "this is being fixed, try again".
    // `nonisolated` — it's a pure mapping over an NSError with no actor state,
    // so tests (and any caller) can use it off the main actor.
    nonisolated static func friendlyMessage(for error: Error) -> String {
        let ns = error as NSError
        guard ns.domain == FirestoreErrorDomain,
              ns.code == FirestoreErrorCode.permissionDenied.rawValue else {
            return ns.localizedDescription
        }
        return "Your account doesn't have access to videos right now. "
             + "This is usually temporary — tap Try Again."
    }

    // Resolve a playable URL: prefer the direct https URL, otherwise turn the
    // Firebase Storage path into a download URL.
    func playbackURL(for video: AssignedVideo) async -> URL? {
        if let url = video.videoURL { return url }
        guard let path = video.storagePath, !path.isEmpty else { return nil }
        return try? await Storage.storage().reference(withPath: path).downloadURL()
    }

    deinit { listener?.remove() }
}
