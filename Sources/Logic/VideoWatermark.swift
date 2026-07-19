import AVFoundation
import UIKit
import CoreImage

// Burning the Palmr mark into video *pixels*.
//
// `PalmrWatermark` (Design/Watermark.swift) has two consumers: a SwiftUI overlay
// for surfaces the app displays, and `drawBurnIn` for pixels the app writes.
// This file owns everything on the pixel side, so the reel editor's export and
// the Released tab's "Save to Photos" brand video identically instead of each
// growing their own compositing code.
//
// Why a burn-in at all: the display overlay lives in the view layer, so it is
// gone the moment a file leaves the app. A user who saved a released class to
// their phone got an unbranded video (task #1075). Only pixels survive the trip
// to Photos, AirDrop, and everywhere the file goes afterwards.
//
// Overlays are composited with a Core Image per-frame handler rather than
// AVVideoCompositionCoreAnimationTool — the animation tool renders its CALayer
// tree on a background thread during export and crashes intermittently.
enum VideoWatermark {

    enum Failure: LocalizedError, Equatable {
        case noVideoTrack, noSession
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .noVideoTrack:  return "This video has no video track to watermark."
            case .noSession:     return "Couldn't start the video export."
            case .failed(let m): return m
            }
        }
    }

    /// Where the reel editor's caption sits by default — normalized, y from top.
    static let defaultTextPos = CGPoint(x: 0.5, y: 0.82)

    // MARK: - Full-length burn-in

    /// Re-encode `assetURL` end to end with the watermark burned into every
    /// frame, preserving audio, and return the new file.
    ///
    /// This re-encodes rather than remuxing, because there is no way to alter
    /// pixels without one — so it costs roughly a playback's worth of time on a
    /// long class recording. The caller is expected to tell the user that
    /// something is happening (see `VideoDownload.Phase`).
    static func burnIn(into assetURL: URL, named filename: String) async throws -> URL {
        let asset = AVURLAsset(url: assetURL)

        guard let srcV = try? await asset.loadTracks(withMediaType: .video).first else {
            throw Failure.noVideoTrack
        }
        let comp = AVMutableComposition()
        guard let dstV = comp.addMutableTrack(withMediaType: .video,
                                              preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw Failure.noVideoTrack
        }

        do {
            // Take the video track's own range, not the asset duration: a file
            // whose audio runs longer than its video would otherwise ask for
            // video frames that don't exist.
            let videoRange = try await srcV.load(.timeRange)
            try dstV.insertTimeRange(videoRange, of: srcV, at: .zero)
            // The video composition reads this to orient frames and derive its
            // render size, so the burned-in mark lands the right way up and in
            // the corner the viewer actually sees.
            dstV.preferredTransform = (try? await srcV.load(.preferredTransform)) ?? .identity

            // Keep the audio. This is a recording of a class — unlike a reel,
            // silence would be a real loss. Clamped to the span the two tracks
            // share so a longer/shorter audio track can't throw.
            if let srcA = try? await asset.loadTracks(withMediaType: .audio).first,
               let dstA = comp.addMutableTrack(withMediaType: .audio,
                                               preferredTrackID: kCMPersistentTrackID_Invalid) {
                let audioRange = try await srcA.load(.timeRange)
                let shared = videoRange.intersection(audioRange)
                if shared.duration > .zero {
                    try dstA.insertTimeRange(shared, of: srcA, at: .zero)
                }
            }
        } catch {
            throw Failure.failed(error.localizedDescription)
        }

        guard let session = AVAssetExportSession(asset: comp,
                                                 presetName: AVAssetExportPresetHighestQuality) else {
            throw Failure.noSession
        }
        session.videoComposition = videoComposition(for: comp)

        // Its own directory, so the caller-supplied name survives verbatim into
        // Photos without colliding with a concurrent save.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("watermark-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let out = dir.appendingPathComponent(mp4Name(filename))

        session.outputURL = out
        session.outputFileType = .mp4
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { cont.resume() }
        }
        guard session.status == .completed else {
            try? FileManager.default.removeItem(at: dir)
            throw Failure.failed(session.error?.localizedDescription ?? "Watermarking didn't complete.")
        }
        return out
    }

    /// Force `.mp4` — the burn-in always re-encodes to H.264/MP4, so carrying a
    /// source `.mov`/`.m4v` extension through would mislabel the asset.
    static func mp4Name(_ filename: String) -> String {
        let stem = (filename as NSString).deletingPathExtension
        return "\(stem.isEmpty ? "video" : stem).mp4"
    }

    // MARK: - Shared compositing

    /// A video composition that draws the watermark — and an optional caption —
    /// over every frame of `asset`. Used by both the reel export and the
    /// full-length burn-in so the two can't drift.
    static func videoComposition(for asset: AVAsset,
                                 text: String = "",
                                 pos: CGPoint = defaultTextPos) -> AVMutableVideoComposition {
        // The overlay is built from the first frame's actual extent rather than
        // from naturalSize + a rotation guess: the filtering handler hands back
        // frames already oriented, so the extent is the truth about where the
        // corner is. It's identical for every frame, hence the cache.
        let cache = OverlayCache()
        return AVMutableVideoComposition(asset: asset) { request in
            let src = request.sourceImage
            let extent = src.extent
            guard let overlay = cache.image(for: extent.size, make: {
                makeOverlay(renderSize: $0, text: text, pos: pos)
            }) else {
                request.finish(with: src, context: nil); return
            }
            let placed = overlay.transformed(by: CGAffineTransform(translationX: extent.origin.x,
                                                                  y: extent.origin.y))
            request.finish(with: placed.composited(over: src).cropped(to: extent), context: nil)
        }
    }

    /// Render the watermark, and the caption when there is one, into a full-frame
    /// transparent image (scale 1 so its pixel size matches renderSize), then hand
    /// back a CIImage to composite per frame.
    static func makeOverlay(renderSize: CGSize, text: String, pos: CGPoint) -> CIImage? {
        guard renderSize.width > 0, renderSize.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let img = UIGraphicsImageRenderer(size: renderSize, format: format).image { _ in
            if !text.isEmpty { drawCaption(text: text, renderSize: renderSize, pos: pos) }
            PalmrWatermark.drawBurnIn(canvasSize: renderSize)
        }
        return CIImage(image: img)
    }

    private static func drawCaption(text: String, renderSize: CGSize, pos: CGPoint) {
        let fontSize = max(14, renderSize.height * 0.045)
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let para = NSMutableParagraphStyle(); para.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white, .paragraphStyle: para]
        let str = text as NSString
        let maxW = renderSize.width * 0.9
        let bounds = str.boundingRect(with: CGSize(width: maxW, height: .greatestFiniteMagnitude),
                                      options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
        let boxW = min(maxW, ceil(bounds.width) + 28), boxH = ceil(bounds.height) + 14
        let cx = renderSize.width * pos.x, cy = renderSize.height * pos.y
        let box = CGRect(x: cx - boxW / 2, y: cy - boxH / 2, width: boxW, height: boxH)
        UIColor.black.withAlphaComponent(0.5).setFill()
        UIBezierPath(roundedRect: box, cornerRadius: 8).fill()
        str.draw(in: box.insetBy(dx: 14, dy: 7), withAttributes: attrs)
    }
}

// Builds the overlay once and hands the same CIImage to every frame. The
// filtering handler runs on AVFoundation's own queue and may be re-entered
// concurrently, so the memo is lock-guarded.
private final class OverlayCache: @unchecked Sendable {
    private let lock = NSLock()
    private var cached: (size: CGSize, image: CIImage?)?

    func image(for size: CGSize, make: (CGSize) -> CIImage?) -> CIImage? {
        lock.lock()
        defer { lock.unlock() }
        if let cached, cached.size == size { return cached.image }
        let made = make(size)
        cached = (size, made)
        return made
    }
}
