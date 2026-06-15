import Foundation
import FirebaseStorage

// Uploads chat attachments to Firebase Storage under the same path prefix the
// web client uses (chat-uploads/{channelId}/), then returns the Attachment to
// record on the message.
struct StorageService {
    private let storage = Storage.storage()

    func upload(data: Data, fileName: String, contentType: String, channelId: String) async throws -> Attachment {
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        let path = "chat-uploads/\(channelId)/\(ts)-\(fileName)"
        let ref = storage.reference(withPath: path)
        let meta = StorageMetadata()
        meta.contentType = contentType
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
}
