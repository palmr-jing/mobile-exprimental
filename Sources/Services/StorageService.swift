import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseStorage

// Uploads chat attachments to Firebase Storage under the same path prefix the
// web client uses (chat-uploads/{channelId}/), then returns the Attachment to
// record on the message.
struct StorageService {
    private let storage = Storage.storage()

    func upload(data: Data, fileName: String, contentType: String, channelId: String) async throws -> Attachment {
        // Why the guard + token fetch: chat-image upload was silently failing.
        // Firestore writes are authenticated (long-lived listeners tolerate a
        // not-yet-settled token), but a one-shot Storage putData carries the Auth
        // token only if the SDK can present a valid one at request time. On a cold
        // launch — or once the cached ID token had expired — the upload could fire
        // before Auth had a usable token, so the chat-uploads rule
        // (request.auth != null) rejected it with storage/unauthorized and the
        // picked image vanished with no message. Fail fast with a precise error,
        // and force a valid (refreshed-if-needed) token to be minted up front so
        // the FirebaseAuth<->Storage interop has one to attach to the request.
        guard let user = Auth.auth().currentUser else {
            throw StorageServiceError.notAuthenticated
        }
        _ = try await user.getIDToken()

        // Resolve the configured bucket explicitly so a misconfiguration surfaces
        // in the console/log rather than silently hitting the wrong (or a
        // non-existent) bucket.
        let bucket = FirebaseApp.app()?.options.storageBucket ?? "(unknown)"
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        let path = "chat-uploads/\(channelId)/\(ts)-\(fileName)"
        let ref = storage.reference(withPath: path)
        let meta = StorageMetadata()
        meta.contentType = contentType
        print("StorageService.upload → gs://\(bucket)/\(path) (\(data.count) bytes, uid=\(user.uid), anon=\(user.isAnonymous))")
        _ = try await ref.putDataAsync(data, metadata: meta)
        let url = try await ref.downloadURL()
        return Attachment(
            url: url.absoluteString,
            name: fileName,
            contentType: contentType,
            size: data.count,
            storagePath: path
        )
    }

    // Human-readable explanation for an upload failure, naming the underlying
    // StorageErrorCode so the surfaced uploadError pinpoints the cause on the next
    // build (e.g. unauthorized vs bucket-not-found) instead of a generic message.
    static func describe(_ error: Error) -> String {
        if let svc = error as? StorageServiceError { return svc.message }
        let ns = error as NSError
        if ns.domain == StorageErrorDomain, let code = StorageErrorCode(rawValue: ns.code) {
            switch code {
            case .unauthorized:
                return "Storage denied the upload (storage/unauthorized) — the request wasn't authenticated. Sign out and back in, then retry."
            case .unauthenticated:
                return "Not signed in to Firebase Storage (storage/unauthenticated). Sign out and back in, then retry."
            case .bucketNotFound:
                return "Storage bucket not found (storage/bucket-not-found) — the app is pointed at the wrong bucket."
            case .objectNotFound:
                return "Upload target not found (storage/object-not-found)."
            case .quotaExceeded:
                return "Storage quota exceeded (storage/quota-exceeded)."
            case .retryLimitExceeded:
                return "Upload timed out (storage/retry-limit-exceeded). Check your connection and retry."
            case .cancelled:
                return "Upload was cancelled."
            default:
                return "Upload failed (storage code \(code.rawValue)). \(ns.localizedDescription)"
            }
        }
        return error.localizedDescription
    }
}

// Errors raised by StorageService before a Storage request is even attempted.
enum StorageServiceError: Error {
    case notAuthenticated

    var message: String {
        switch self {
        case .notAuthenticated:
            return "You're not signed in to Firebase, so the image can't be uploaded. Sign out and back in, then retry."
        }
    }
}
