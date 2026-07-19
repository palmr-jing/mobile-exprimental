import Testing
import Foundation
@testable import MobileCommander

// The decision-making behind "Save to Photos" — which container Photos will
// accept and what the saved file is named — without a network or a Photos prompt.
struct VideoDownloadTests {

    // MARK: - fileExtension

    @Test func readsExtensionFromAPlainURL() {
        #expect(VideoDownload.fileExtension(for: URL(string: "https://x.test/a/clip.mp4")!) == "mp4")
    }

    @Test func ignoresQueryStringWhenReadingTheExtension() {
        let u = URL(string: "https://x.test/clip.MOV?alt=media&token=abc-123")!
        #expect(VideoDownload.fileExtension(for: u) == "mov")
    }

    // Firebase Storage percent-encodes the object path; the real container is
    // only visible once it's decoded.
    @Test func decodesAFirebaseStorageObjectPath() {
        let u = URL(string: "https://firebasestorage.googleapis.com/v0/b/app/o/wallcam%2Freels%2Freel-30.webm?alt=media&token=t")!
        #expect(VideoDownload.fileExtension(for: u) == "webm")
    }

    @Test func noExtensionWhenTheURLHasNone() {
        #expect(VideoDownload.fileExtension(for: URL(string: "https://x.test/o/clip")!) == "")
    }

    // A trailing hash isn't a container.
    @Test func ignoresALongHashTail() {
        #expect(VideoDownload.fileExtension(for: URL(string: "https://x.test/clip.9f3e21b4c7ae")!) == "")
    }

    // MARK: - isPhotosCompatible

    @Test(arguments: ["https://x.test/a.mp4", "https://x.test/a.mov", "https://x.test/a.m4v",
                      "https://x.test/a"])
    func acceptsContainersPhotosCanIngest(_ raw: String) {
        #expect(VideoDownload.isPhotosCompatible(URL(string: raw)!))
    }

    @Test(arguments: ["https://x.test/a.webm", "https://x.test/a.mkv", "https://x.test/a.avi",
                      "https://firebasestorage.googleapis.com/v0/b/app/o/r%2Fc.webm?alt=media&token=t"])
    func rejectsContainersIOSCannotStore(_ raw: String) {
        #expect(!VideoDownload.isPhotosCompatible(URL(string: raw)!))
    }

    // The guard has to fire BEFORE the download, so the user isn't made to wait
    // for a file that can never be saved.
    @Test func unsupportedFormatFailsWithAnActionableMessage() async {
        let webm = URL(string: "https://x.test/kids-bjj.webm")!
        await #expect(throws: VideoDownload.Failure.unsupportedFormat("webm")) {
            try await VideoDownload.saveToPhotos(from: webm, className: "Kids BJJ", camera: "front")
        }
        let message = VideoDownload.Failure.unsupportedFormat("webm").errorDescription ?? ""
        #expect(message.contains(".webm"))
        #expect(message.contains("MP4"))
    }

    // MARK: - suggestedFilename

    @Test func namesTheFileAfterTheClassAndCamera() {
        let name = VideoDownload.suggestedFilename(
            className: "IMA Fit + Tiny Tigers", camera: "front-right",
            url: URL(string: "https://x.test/a.mp4")!)
        #expect(name == "IMA-Fit-Tiny-Tigers-front-right.mp4")
    }

    // Photos types the asset from the extension, so there is always one.
    @Test func defaultsToMP4WhenTheURLHasNoExtension() {
        let name = VideoDownload.suggestedFilename(
            className: "Muay Thai", camera: "front", url: URL(string: "https://x.test/o/clip")!)
        #expect(name == "Muay-Thai-front.mp4")
    }

    @Test func keepsTheOriginalContainerInTheName() {
        let name = VideoDownload.suggestedFilename(
            className: "Sparring", camera: "realsense", url: URL(string: "https://x.test/a.mov")!)
        #expect(name == "Sparring-realsense.mov")
    }

    @Test func fallsBackWhenThereIsNothingToNameTheFileAfter() {
        let name = VideoDownload.suggestedFilename(
            className: "", camera: "", url: URL(string: "https://x.test/a.mp4")!)
        #expect(name == "recording.mp4")
    }

    // No stray separators from punctuation-heavy class names.
    @Test func producesAFilesystemSafeName() {
        let name = VideoDownload.suggestedFilename(
            className: "Muay Thai / Adult+Teen (6:00)", camera: "front",
            url: URL(string: "https://x.test/a.mp4")!)
        #expect(!name.contains("/"))
        #expect(!name.contains(":"))
        #expect(!name.contains("--"))
        #expect(name.hasSuffix(".mp4"))
    }
}
