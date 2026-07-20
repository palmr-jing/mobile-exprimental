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
    // The uid we're subscribed for. Keyed on the user rather than a plain
    // "did we start" flag so a different signed-in user re-subscribes instead of
    // inheriting the previous session's listener (matching VideoService).
    private var currentUID: String?

    // Begin the live subscription for the signed-in user. Idempotent: safe to
    // call from `.task` on every appearance. Only a signed-in user may read (see
    // the collection's rule), so the caller gates this behind an authenticated
    // session.
    func start(uid: String) {
        guard uid != currentUID else { return }
        subscribe(uid: uid)
    }

    // Re-attach after a failure (task #1068). Firestore does NOT retry a snapshot
    // listener that failed with permission-denied — it tears the listener down for
    // good. Without this the Released tab stayed on "Couldn't load recordings"
    // for the rest of the process, even once the user's token was valid again;
    // the only way out was force-quitting the app.
    func retry() {
        guard let uid = currentUID else { return }
        subscribe(uid: uid)
    }

    private func subscribe(uid: String) {
        stop()
        currentUID = uid
        isLoading = true
        listener = db.collection("released_recordings")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false
                    if let error {
                        self.errorMessage = Self.message(for: error)
                        // The listener is already dead; drop our handle so a
                        // retry attaches a fresh one rather than a no-op.
                        self.listener?.remove()
                        self.listener = nil
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
        currentUID = nil
    }

    // Shown when the read is rejected by the collection's security rule. Firestore
    // words this as "Missing or insufficient permissions.", which told the
    // reporter of #1068 nothing about what to do next.
    nonisolated static let permissionDeniedMessage =
        "Your account doesn't have access to released recordings yet. Try again, or sign out and back in — if it keeps happening, ask an admin to check your access."

    // Translate the SDK's error strings into something a user can act on. Anything
    // we don't recognise falls through to the original text rather than being
    // swallowed, so unexpected failures stay diagnosable.
    //
    // `nonisolated` (and static) so it's a pure function: callable off the main
    // actor, and testable without constructing the service — which would spin up
    // `Firestore.firestore()` and need a configured FirebaseApp.
    nonisolated static func message(for error: Error) -> String {
        let ns = error as NSError
        guard ns.domain == FirestoreErrorDomain else { return ns.localizedDescription }
        switch ns.code {
        case FirestoreErrorCode.Code.permissionDenied.rawValue,
             FirestoreErrorCode.Code.unauthenticated.rawValue:
            return permissionDeniedMessage
        case FirestoreErrorCode.Code.unavailable.rawValue:
            return "Can't reach the server. Check your connection and try again."
        default:
            return ns.localizedDescription
        }
    }

    deinit { listener?.remove() }
}
