import Foundation
import SwiftUI
import PhotosUI
import CoreTransferable
import UniformTypeIdentifiers

// Loads a file the user picked in a `PhotosPicker` into raw bytes ready to
// upload to Firebase Storage.
//
// Why this exists: the chat composers used to load every picked item with
// `item.loadTransferable(type: Data.self)`. That works for images but returns
// `nil` for VIDEOS — PhotosUI vends a movie as a *file* representation, not a
// data representation, so the `Data` request finds nothing and the attach
// silently no-ops (the reported "attaching video not working"). Movies must be
// loaded through their file URL (see `PickedMovie`) and then read off disk.
enum PhotoAttachmentLoader {

    struct Loaded {
        let data: Data
        let fileName: String
        let mime: String
        let isImage: Bool
    }

    struct Classification: Equatable {
        let mime: String
        let ext: String
        let isImage: Bool
        let isVideo: Bool
    }

    enum LoadError: Error { case unreadable }

    // Decide the MIME type, file extension, and image/video kind from the
    // content types a picked item advertises. Pure so the image-vs-video
    // branch — the crux of the fix — is unit-testable without a live picker.
    static func classify(_ types: [UTType]) -> Classification {
        let primary = types.first
        var mime = primary?.preferredMIMEType ?? "application/octet-stream"
        var ext = primary?.preferredFilenameExtension ?? "dat"

        let isImage = types.contains { $0.conforms(to: .image) } || mime.hasPrefix("image/")
        let isVideo = !isImage
            && (types.contains { $0.conforms(to: .movie) } || mime.hasPrefix("video/"))

        // A bare `public.movie` UTType has no preferred MIME/extension, so an
        // otherwise-valid video would upload as application/octet-stream and then
        // render as a generic file link instead of a player (Presence.mediaType
        // keys off a "video/" prefix). Pin it to a concrete video type so the
        // message is classified — and rendered — as a video.
        if isVideo && !mime.hasPrefix("video/") {
            mime = "video/quicktime"
            ext = "mov"
        }
        return Classification(mime: mime, ext: ext, isImage: isImage, isVideo: isVideo)
    }

    static func fileName(ext: String, now: Date) -> String {
        "upload-\(Int(now.timeIntervalSince1970)).\(ext)"
    }

    // Load the picked item's bytes. Images come straight back as `Data`; movies
    // are copied out to a temp file by `PickedMovie` and then read (memory-mapped
    // to avoid pulling a large clip fully into RAM). Throws `.unreadable` when the
    // representation can't be produced so callers can surface a real error instead
    // of the old silent return.
    static func load(_ item: PhotosPickerItem, now: Date = Date()) async throws -> Loaded {
        let c = classify(item.supportedContentTypes)
        let name = fileName(ext: c.ext, now: now)

        if c.isVideo {
            guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                throw LoadError.unreadable
            }
            defer { try? FileManager.default.removeItem(at: movie.url) }
            let data = try Data(contentsOf: movie.url, options: .mappedIfSafe)
            return Loaded(data: data, fileName: name, mime: c.mime, isImage: false)
        }

        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw LoadError.unreadable
        }
        return Loaded(data: data, fileName: name, mime: c.mime, isImage: c.isImage)
    }
}

// A movie copied out of the Photos picker. PhotosUI hands us a file that is
// deleted the instant the import closure returns, so we copy it into our temp
// directory and hold that URL. Callers delete it once the bytes are read.
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("emma-attach-\(UUID().uuidString)")
                .appendingPathExtension(ext)
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return PickedMovie(url: dest)
        }
    }
}
