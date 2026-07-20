import Testing
import Foundation
import FirebaseFirestore
@testable import MobileCommander

// Task #1068 ("Jing can't see anything"): the Released tab showed Firestore's own
// "Missing or insufficient permissions." with no way forward. These cover the
// translation of SDK errors into text a user can act on.
//
// `message(for:)` is static, so exercising it never constructs the service — and
// so never touches `Firestore.firestore()`, which would need a configured
// FirebaseApp under the hermetic unit-test host.
struct ReleasedRecordingsErrorTests {
    private func firestoreError(_ code: FirestoreErrorCode.Code, _ description: String) -> NSError {
        NSError(domain: FirestoreErrorDomain, code: code.rawValue,
                userInfo: [NSLocalizedDescriptionKey: description])
    }

    // The exact failure in the report's screenshot.
    @Test func permissionDeniedBecomesActionableText() {
        let msg = ReleasedRecordingsService.message(
            for: firestoreError(.permissionDenied, "Missing or insufficient permissions."))

        #expect(msg == ReleasedRecordingsService.permissionDeniedMessage)
        #expect(!msg.contains("insufficient permissions"))
        // It has to tell the user what to actually do next.
        #expect(msg.localizedCaseInsensitiveContains("sign out"))
    }

    // An expired/absent token surfaces as unauthenticated rather than denied;
    // the remedy for the user is the same.
    @Test func unauthenticatedUsesTheSameGuidance() {
        let msg = ReleasedRecordingsService.message(
            for: firestoreError(.unauthenticated, "Request had invalid authentication credentials."))
        #expect(msg == ReleasedRecordingsService.permissionDeniedMessage)
    }

    @Test func unavailableReadsAsAConnectionProblem() {
        let msg = ReleasedRecordingsService.message(
            for: firestoreError(.unavailable, "The service is currently unavailable."))
        #expect(msg.localizedCaseInsensitiveContains("connection"))
    }

    // Anything unrecognised must stay diagnosable rather than being flattened
    // into a generic apology.
    @Test func unrecognisedFirestoreCodeKeepsItsOriginalText() {
        let msg = ReleasedRecordingsService.message(
            for: firestoreError(.dataLoss, "Unrecoverable data loss or corruption."))
        #expect(msg == "Unrecoverable data loss or corruption.")
    }

    @Test func nonFirestoreErrorKeepsItsOriginalText() {
        let err = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut,
                          userInfo: [NSLocalizedDescriptionKey: "The request timed out."])
        #expect(ReleasedRecordingsService.message(for: err) == "The request timed out.")
    }
}
