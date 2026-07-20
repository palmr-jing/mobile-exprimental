import Foundation

// Decides when a Firestore snapshot listener must be (re)attached.
//
// Pulled out of the services as a pure value type so the "is this subscription
// still live?" logic is unit-testable without a live Firestore — the bug in
// #1070 was entirely in this decision, and it was untestable while it lived as a
// bare `started` Bool inside a service that builds `Firestore.firestore()` in
// its initializer.
//
// The failure it exists to prevent: Firestore TERMINATES a snapshot listener
// when it errors (notably `permission-denied`, which the app can hit on a
// token-refresh gap, on a listener that outlives a sign-out, or when the
// listener attaches a moment before the auth token propagates). A one-shot
// `started` flag never clears, so the listener is never re-attached and the
// screen shows its error forever. Keying on the signed-in identity — and
// treating a failed listener as "not attached" — makes the state recoverable.
struct ListenerGate: Equatable {
    /// The identity the listener is currently attached for, or nil when detached.
    private(set) var attachedKey: String?
    /// True once the attached listener has errored. Firestore has already torn it
    /// down at this point, so the gate must not consider it live.
    private(set) var hasFailed = false

    /// True when the listener is up and healthy for `key`.
    func isLive(for key: String?) -> Bool {
        guard let key, !key.isEmpty else { return false }
        return attachedKey == key && !hasFailed
    }

    /// Whether the caller should attach a listener for this identity, recording
    /// the attachment when it says yes.
    ///
    /// Returns false — and detaches — for a nil/empty key: an unauthenticated
    /// caller can only get `permission-denied` from a rule that requires
    /// `request.auth != null`, so there is no point attaching at all.
    mutating func shouldAttach(for key: String?) -> Bool {
        guard let key, !key.isEmpty else {
            reset()
            return false
        }
        // Already live for this identity — nothing to do. A previously FAILED
        // listener falls through and re-attaches, so returning to the screen (or
        // switching identity) retries rather than showing a dead error state.
        if isLive(for: key) { return false }
        attachedKey = key
        hasFailed = false
        return true
    }

    /// Record that the attached listener errored. Firestore has dropped it, so
    /// the next `shouldAttach(for:)` re-attaches instead of assuming it's live.
    mutating func markFailed() {
        hasFailed = true
    }

    /// Forget the attachment entirely, so the next `shouldAttach(for:)` attaches
    /// even for the same identity. Used by an explicit user-driven retry and on
    /// teardown.
    mutating func reset() {
        attachedKey = nil
        hasFailed = false
    }
}
