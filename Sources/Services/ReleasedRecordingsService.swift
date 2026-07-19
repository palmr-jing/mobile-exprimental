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
// / Missing or insufficient permissions" until the app was force-quit (#1070).
@MainActor
final class ReleasedRecordingsService: ObservableObject {
    @Published var recordings: [ReleasedRecording] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var gate = ListenerGate()

    // Shown when the collection's `request.auth != null` rule rejects the read.
    // Because the rule asks only for *any* signed-in user, a denial means the
    // request carried no valid auth token — a stale/expired session rather than
    // an account that lacks access — so the copy points at the action that
    // actually fixes it. Raw Firestore text ("Missing or insufficient
    // permissions.") told the user nothing they could act on.
    static let sessionExpiredMessage =
        "Your session expired before the recordings could load. Try again, or sign out and back in."

    /// Begin (or re-establish) the live subscription for the signed-in user.
    /// Idempotent for a healthy listener, so it is safe to call from `.task` on
    /// every appearance; re-attaches when the identity changes or the previous
    /// listener died.
    func start(uid: String?) {
        guard gate.shouldAttach(for: uid) else { return }
        attach()
    }

    /// User-driven retry from the error state. Forces a fresh attach even for the
    /// same identity.
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

    /// Human-facing copy for a listener error. Pure, so the permission-denied
    /// mapping is unit-testable without a live Firestore.
    nonisolated static func message(for error: Error) -> String {
        let ns = error as NSError
        if ns.domain == FirestoreErrorDomain,
           ns.code == FirestoreErrorCode.permissionDenied.rawValue {
            return sessionExpiredMessage
        }
        return error.localizedDescription
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

    deinit { listener?.remove() }
}
