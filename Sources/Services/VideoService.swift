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
                        self.errorMessage = error.localizedDescription
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

    // Resolve a playable URL: prefer the direct https URL, otherwise turn the
    // Firebase Storage path into a download URL.
    func playbackURL(for video: AssignedVideo) async -> URL? {
        if let url = video.videoURL { return url }
        guard let path = video.storagePath, !path.isEmpty else { return nil }
        return try? await Storage.storage().reference(withPath: path).downloadURL()
    }

    deinit { listener?.remove() }
}
