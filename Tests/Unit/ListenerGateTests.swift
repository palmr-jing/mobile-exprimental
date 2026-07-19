import Testing
import Foundation
@testable import MobileCommander

// Covers the subscription-lifecycle decision behind #1070 ("Can't load
// recordings" / "Missing or insufficient permissions" on the Released tab).
//
// The old ReleasedRecordingsService guarded on a one-shot `started` Bool that
// nothing ever reset. Firestore tears a snapshot listener down when it errors, so
// a single transient `permission-denied` left the tab permanently dead: the view
// re-ran its `.task` on every appearance, `start()` no-oped, and no listener was
// ever attached again. These tests pin the recovery paths.
//
// NOTE: every `shouldAttach` call is bound to a `let` before being asserted on.
// `#expect` captures its expression into an escaping closure, where the captured
// `gate` is immutable — calling a mutating member inside the macro fails to
// compile (and, because the build script's exit code masked it, silently skipped
// this whole file on the first run).
struct ListenerGateTests {
    @Test func attachesOnceForAHealthyIdentity() {
        var gate = ListenerGate()
        let first = gate.shouldAttach(for: "uid-1")
        // Repeat calls (the view's `.task` re-firing on every appearance) must not
        // churn a healthy listener.
        let second = gate.shouldAttach(for: "uid-1")
        let third = gate.shouldAttach(for: "uid-1")
        #expect(first)
        #expect(!second)
        #expect(!third)
        #expect(gate.isLive(for: "uid-1"))
    }

    // The core regression: a failed listener is NOT live, so the next appearance
    // re-attaches instead of leaving the error on screen forever.
    @Test func reattachesAfterAFailure() {
        var gate = ListenerGate()
        let attached = gate.shouldAttach(for: "uid-1")
        gate.markFailed()
        let liveAfterFailure = gate.isLive(for: "uid-1")
        let reattached = gate.shouldAttach(for: "uid-1")

        #expect(attached)
        #expect(!liveAfterFailure, "a torn-down listener must not count as live")
        #expect(reattached, "a failed listener must be re-attached")
        #expect(gate.isLive(for: "uid-1"), "re-attaching should clear the failed state")
    }

    // Signing in as someone else must move the subscription to the new identity —
    // the behaviour VideoService already had by keying on email.
    @Test func reattachesWhenIdentityChanges() {
        var gate = ListenerGate()
        let first = gate.shouldAttach(for: "uid-1")
        let second = gate.shouldAttach(for: "uid-2")

        #expect(first)
        #expect(second)
        #expect(gate.isLive(for: "uid-2"))
        #expect(!gate.isLive(for: "uid-1"))
    }

    // Sign-out: never attach without an identity. The collection's rule is
    // `request.auth != null`, so an unauthenticated attach can only be denied.
    @Test func neverAttachesWithoutAnIdentity() {
        var gate = ListenerGate()
        let nilKey = gate.shouldAttach(for: nil)
        let emptyKey = gate.shouldAttach(for: "")

        #expect(!nilKey)
        #expect(!emptyKey)
        #expect(!gate.isLive(for: nil))
    }

    // Signing out and back in as the same user must re-attach — previously the
    // `started` flag survived the round trip and the tab stayed empty/errored.
    @Test func reattachesAfterSignOutAndBackIn() {
        var gate = ListenerGate()
        let signedIn = gate.shouldAttach(for: "uid-1")
        let signedOut = gate.shouldAttach(for: nil)      // sign-out detaches
        let signedBackIn = gate.shouldAttach(for: "uid-1")

        #expect(signedIn)
        #expect(!signedOut)
        #expect(signedBackIn, "signing back in must re-attach")
    }

    // An explicit "Try again" forces a fresh attach even for a healthy identity.
    @Test func resetForcesAFreshAttach() {
        var gate = ListenerGate()
        let first = gate.shouldAttach(for: "uid-1")
        let secondWhileLive = gate.shouldAttach(for: "uid-1")
        gate.reset()
        let afterReset = gate.shouldAttach(for: "uid-1")

        #expect(first)
        #expect(!secondWhileLive)
        #expect(afterReset)
    }
}

// The error copy shown on the Released tab. A `permission-denied` on a rule that
// only asks for `request.auth != null` means the request carried no valid token —
// a stale session — so the message must point at the fix rather than echoing
// Firestore's opaque "Missing or insufficient permissions."
struct ReleasedRecordingsErrorMessageTests {
    private func firestoreError(_ code: Int) -> NSError {
        NSError(domain: "FIRFirestoreErrorDomain", code: code,
                userInfo: [NSLocalizedDescriptionKey: "Missing or insufficient permissions."])
    }

    @Test func permissionDeniedExplainsTheSession() {
        // FirestoreErrorCode.permissionDenied == 7 (gRPC PERMISSION_DENIED).
        let msg = ReleasedRecordingsService.message(for: firestoreError(7))
        #expect(msg == ReleasedRecordingsService.sessionExpiredMessage)
        #expect(!msg.contains("insufficient permissions"),
                "raw Firestore copy gives the user nothing to act on")
    }

    @Test func otherErrorsKeepTheirOwnDescription() {
        let offline = NSError(domain: "FIRFirestoreErrorDomain", code: 14,
                              userInfo: [NSLocalizedDescriptionKey: "The service is currently unavailable."])
        #expect(ReleasedRecordingsService.message(for: offline) == "The service is currently unavailable.")
    }
}
