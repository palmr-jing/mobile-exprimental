import Foundation
import FirebaseFirestore
import Combine

// Live feed of the class recordings released to the app from
// manage.everbot.org's Recordings tab. Backed by the `released_recordings`
// collection its "Release to app" action writes to — one doc per class, doc id =
// plan_id, with all camera angles grouped in a `videos` array.
//
// The read rule is `allow read: if request.auth != null`, so any signed-in user
// sees every released class (this isn't scoped per-email like commander_videos).
// We sort client-side rather than ordering in the query so a doc missing
// `released_at` still appears (an `.order(by:)` would silently drop it) and to
// avoid a composite index. The collection is small (one doc per class).
@MainActor
final class ReleasedRecordingsService: ObservableObject {
    @Published var recordings: [ReleasedRecording] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var started = false

    // Begin the live subscription. Idempotent: safe to call from `.task` on every
    // appearance. Only a signed-in user may read (see the collection's rule), so
    // the caller gates this behind an authenticated session.
    func start() {
        guard !started else { return }
        started = true
        isLoading = true
        listener = db.collection("released_recordings")
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
                        .compactMap { ReleasedRecording.from(id: $0.documentID, data: $0.data()) }
                    self.recordings = ReleasedRecording.sortedNewestFirst(parsed)
                }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
        started = false
    }

    deinit { listener?.remove() }
}
