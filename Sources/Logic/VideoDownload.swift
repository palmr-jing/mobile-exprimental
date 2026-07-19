import Foundation
import Photos

// Downloading a released recording to the user's phone (Photos library).
//
// Factored out of the view so the decision-making — which container Photos will
// accept, what the saved file is called — is unit-testable without a network,
// a Photos authorization prompt, or a simulator.
//
// The format guard matters: the release pipeline can emit WebM (task #1049 —
// Chrome's MediaRecorder can't encode H.264), and both AVPlayer and Photos
// reject it. Without the guard the user taps Save, waits through a full
// download, and gets an opaque Photos error at the very end.
enum VideoDownload {

    enum Failure: LocalizedError, Equatable {
        case unsupportedFormat(String)      // container Photos won't ingest
        case download(String)
        case watermark(String)
        case notAuthorized
        case photos(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let ext):
                let name = ext.isEmpty ? "This recording's format" : ".\(ext) video"
                return "\(name) can't be saved to Photos on iOS. Ask for an MP4 release of this class."
            case .download(let m):
                return "Couldn't download the video. \(m)"
            case .watermark(let m):
                return "Couldn't add the Palmr watermark, so the video wasn't saved. \(m)"
            case .notAuthorized:
                return "Allow photo access in Settings › Emma › Photos, then try again."
            case .photos(let m):
                return "Couldn't save to Photos. \(m)"
            }
        }
    }

    /// What the save is doing right now, so the button can say so. Watermarking
    /// re-encodes the whole recording and is by far the slowest step — leaving
    /// it unlabelled reads as a hang on a long class.
    enum Phase: Equatable {
        case downloading, watermarking, saving
    }

    // MARK: - Pure helpers

    /// Lowercased container extension for a media URL, ignoring query strings.
    /// Firebase Storage URLs percent-encode their path separators
    /// (`/o/wallcam%2Freels%2Freel.webm?alt=media&token=…`); `URL.path` decodes
    /// them, so `pathExtension` still lands on the real container.
    static func fileExtension(for url: URL) -> String {
        let ext = URL(fileURLWithPath: url.path).pathExtension.lowercased()
        // Ignore anything that isn't a plausible container — a URL ending in a
        // long hash ("…/o/clip.9f3e21b4c7ae") has no meaningful extension.
        let plausible = (1...5).contains(ext.count) && ext.allSatisfy { $0.isLetter || $0.isNumber }
        return plausible ? ext : ""
    }

    /// Containers iOS/Photos cannot ingest. Anything else (including an unknown
    /// or absent extension) is attempted — a URL with no extension is common and
    /// is usually H.264, and Photos gives a real error if it isn't.
    static let incompatibleContainers: Set<String> = ["webm", "mkv", "avi", "ogg", "ogv", "flv", "wmv"]

    static func isPhotosCompatible(_ url: URL) -> Bool {
        !incompatibleContainers.contains(fileExtension(for: url))
    }

    /// Filename for the downloaded copy: `IMA-Fit-Tiny-Tigers-front.mp4`.
    /// Photos infers the asset type from the extension, so an extension is always
    /// present (defaulting to mp4) and the stem is filesystem-safe.
    static func suggestedFilename(className: String, camera: String, url: URL) -> String {
        let ext = fileExtension(for: url)
        let stem = [className, camera]
            .map(slug)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return "\(stem.isEmpty ? "recording" : stem).\(ext.isEmpty ? "mp4" : ext)"
    }

    private static func slug(_ s: String) -> String {
        let allowed = s.map { ch -> Character in
            ch.isLetter || ch.isNumber ? ch : "-"
        }
        // Collapse runs of "-" and trim the ends.
        return String(allowed).split(separator: "-").joined(separator: "-")
    }

    // MARK: - Download + save

    /// Download `url`, burn the Palmr watermark into it, and add it to the
    /// user's Photos library. Throws a `Failure` with a message that is safe to
    /// show verbatim.
    ///
    /// The watermark step is not optional and has no silent fallback: saving the
    /// original bytes when the burn-in fails would put an unbranded copy of a
    /// class recording on someone's phone, which is exactly the bug this path
    /// was changed to fix (#1075). Failing loudly keeps the guarantee honest.
    static func saveToPhotos(from url: URL, className: String, camera: String,
                             progress: @MainActor (Phase) -> Void = { _ in }) async throws {
        guard isPhotosCompatible(url) else {
            throw Failure.unsupportedFormat(fileExtension(for: url))
        }
        guard try await requestAddAuthorization() else { throw Failure.notAuthorized }

        await progress(.downloading)
        let local = try await download(url, named: suggestedFilename(className: className, camera: camera, url: url))

        await progress(.watermarking)
        let branded: URL
        do {
            branded = try await VideoWatermark.burnIn(
                into: local,
                named: suggestedFilename(className: className, camera: camera, url: url))
        } catch {
            try? FileManager.default.removeItem(at: local.deletingLastPathComponent())
            throw Failure.watermark((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
        // Drop the unbranded original before handing the copy to Photos: a class
        // recording is large and holding both doubles peak temp usage.
        try? FileManager.default.removeItem(at: local.deletingLastPathComponent())
        defer { try? FileManager.default.removeItem(at: branded.deletingLastPathComponent()) }

        await progress(.saving)
        try await addToLibrary(branded)
    }

    /// Download to a uniquely-named temp file that keeps the media extension.
    static func download(_ url: URL, named filename: String) async throws -> URL {
        let (temp, response) = try await URLSession.shared.download(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            try? FileManager.default.removeItem(at: temp)
            throw Failure.download("The server returned \(http.statusCode).")
        }
        // URLSession's temp file has no extension; Photos needs one to type the asset.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("download-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dest = dir.appendingPathComponent(filename)
            try FileManager.default.moveItem(at: temp, to: dest)
            return dest
        } catch {
            try? FileManager.default.removeItem(at: temp)
            throw Failure.download(error.localizedDescription)
        }
    }

    private static func requestAddAuthorization() async throws -> Bool {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if current == .authorized || current == .limited { return true }
        if current == .denied || current == .restricted { return false }
        let granted = await withCheckedContinuation { (cont: CheckedContinuation<PHAuthorizationStatus, Never>) in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { cont.resume(returning: $0) }
        }
        return granted == .authorized || granted == .limited
    }

    private static func addToLibrary(_ fileURL: URL) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
            } completionHandler: { ok, error in
                if ok { cont.resume() }
                else { cont.resume(throwing: Failure.photos(error?.localizedDescription
                    ?? "The video may be in a format iOS can't store.")) }
            }
        }
    }
}
