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
//
// The subscription is keyed on the signed-in uid via `ListenerGate`, mirroring
// VideoService's keying on email. It used to guard on a one-shot `started` Bool
// that nothing ever reset, which made a `permission-denied` permanent: Firestore
// tears the listener down on error, so the tab showed "Couldn't load recordings
// / Missing or insufficient permissions" until the app was force-quit (#1068/#1070).
@MainActor
final class ReleasedRecordingsService: ObservableObject {
    @Published var recordings: [ReleasedRecording] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var gate = ListenerGate()

    /// Begin (or re-establish) the live subscription for the signed-in user.
    /// Idempotent for a healthy listener, so it is safe to call from `.task` on
    /// every appearance; re-attaches when the identity changes or the previous
    /// listener died.
    func start(uid: String?) {
        guard gate.shouldAttach(for: uid) else { return }
        attach()
    }

    /// User-driven retry from the error state. Forces a fresh attach even for the
    /// same identity. Firestore does NOT retry a snapshot listener that failed with
    /// permission-denied — it tears the listener down for good — so without this the
    /// Released tab stayed on "Couldn't load recordings" for the rest of the
    /// process, even once the user's token was valid again (#1068/#1070).
    func retry(uid: String?) {
        gate.reset()
        start(uid: uid)
    }

    private func attach() {
        detachListener()
        isLoading = true
        errorMessage = nil
        listener = db.collection("released_recordings")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false
                    if let error {
                        // Firestore has already torn this listener down; mark it
                        // dead so returning to the tab (or tapping Try again)
                        // attaches a new one instead of waiting on a corpse.
                        self.gate.markFailed()
                        self.detachListener()
                        self.errorMessage = Self.message(for: error)
                        return
                    }
                    self.errorMessage = nil
                    let parsed = (snapshot?.documents ?? [])
                        .compactMap { ReleasedRecording.from(id: $0.documentID, data: $0.data()) }
                    self.recordings = ReleasedRecording.sortedNewestFirst(parsed)
                }
            }
    }

    /// Tear down on sign-out so a listener can't outlive the session that
    /// authorized it (and then fail permanently against the next one).
    func stop() {
        detachListener()
        gate.reset()
        recordings = []
        errorMessage = nil
        isLoading = false
    }

    private func detachListener() {
        listener?.remove()
        listener = nil
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
