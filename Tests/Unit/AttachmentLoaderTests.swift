import Testing
import Foundation
import UniformTypeIdentifiers
@testable import MobileCommander

// Locks the picked-attachment classification that gates the image-vs-video
// branch in the chat composers. The bug (#1076: "attaching video not working")
// was that videos never reached the upload path; these assert a movie is
// recognized as a video and pinned to a video/* MIME so it renders as a player.
struct AttachmentLoaderTests {

    @Test func quickTimeMovieIsVideo() {
        let c = PhotoAttachmentLoader.classify([.quickTimeMovie])
        #expect(c.isVideo)
        #expect(!c.isImage)
        #expect(c.mime.hasPrefix("video/"))
    }

    @Test func mpeg4MovieKeepsMp4Mime() {
        let c = PhotoAttachmentLoader.classify([.mpeg4Movie])
        #expect(c.isVideo)
        #expect(c.mime == "video/mp4")
        // Presence must route it to the video renderer, not a file link.
        #expect(Presence.mediaType(c.mime) == .video)
    }

    // A bare public.movie has no preferred MIME/extension; without normalization
    // it would upload as application/octet-stream and render as a generic file.
    @Test func bareMovieIsPinnedToVideoType() {
        let c = PhotoAttachmentLoader.classify([.movie])
        #expect(c.isVideo)
        #expect(c.mime == "video/quicktime")
        #expect(c.ext == "mov")
        #expect(Presence.mediaType(c.mime) == .video)
    }

    @Test func jpegIsImage() {
        let c = PhotoAttachmentLoader.classify([.jpeg])
        #expect(c.isImage)
        #expect(!c.isVideo)
        #expect(c.mime == "image/jpeg")
    }

    @Test func pngIsImage() {
        let c = PhotoAttachmentLoader.classify([.png])
        #expect(c.isImage)
        #expect(!c.isVideo)
    }

    @Test func pdfIsNeitherImageNorVideo() {
        let c = PhotoAttachmentLoader.classify([.pdf])
        #expect(!c.isImage)
        #expect(!c.isVideo)
        #expect(Presence.mediaType(c.mime) == .file)
    }

    @Test func emptyTypesFallBackToOpaqueFile() {
        let c = PhotoAttachmentLoader.classify([])
        #expect(!c.isImage)
        #expect(!c.isVideo)
        #expect(c.mime == "application/octet-stream")
        #expect(c.ext == "dat")
    }

    @Test func fileNameUsesExtensionAndTimestamp() {
        let name = PhotoAttachmentLoader.fileName(ext: "mov", now: Date(timeIntervalSince1970: 1_700_000_000))
        #expect(name == "upload-1700000000.mov")
    }
}
