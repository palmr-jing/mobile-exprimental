import AVFoundation
import UIKit
import CoreImage

// The reel-editor export pipeline, factored out of the view so it can be tested
// without UI: trim to [start, end], optionally change speed, drop audio, and
// burn in the Palmr watermark plus an optional text caption, then write an .mp4.
// Pure inputs → output URL.
//
// The watermark is unconditional. Every clip this app writes leaves with Palmr
// branding burned into its pixels — there is no export path that skips it, so a
// reel shared into chat or saved out stays attributed to Palmr.
//
// Overlays are burned in with a Core Image per-frame handler rather than
// AVVideoCompositionCoreAnimationTool — the animation tool renders its CALayer
// tree on a background thread during export and crashes intermittently.
enum ReelExport {
    struct Options {
        var start: Double
        var end: Double
        var speed: Double = 1.0
        var muted: Bool = false
        var text: String = ""
        var textPos: CGPoint = CGPoint(x: 0.5, y: 0.82)  // normalized, y from top
    }

    enum Failure: LocalizedError {
        case emptyRange, noVideoTrack, noSession, failed(String)
        var errorDescription: String? {
            switch self {
            case .emptyRange:    return "Nothing to export — trim a segment first."
            case .noVideoTrack:  return "This clip has no video track."
            case .noSession:     return "Couldn't start the video export."
            case .failed(let m): return m
            }
        }
    }

    static func export(assetURL: URL, options o: Options) async throws -> URL {
        guard o.end > o.start else { throw Failure.emptyRange }
        let asset = AVURLAsset(url: assetURL)
        let range = CMTimeRange(start: CMTime(seconds: o.start, preferredTimescale: 600),
                                end: CMTime(seconds: o.end, preferredTimescale: 600))

        let comp = AVMutableComposition()
        guard let srcV = try? await asset.loadTracks(withMediaType: .video).first,
              let dstV = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw Failure.noVideoTrack
        }
        let transform = (try? await srcV.load(.preferredTransform)) ?? .identity
        do {
            try dstV.insertTimeRange(range, of: srcV, at: .zero)
            // The video composition reads this to orient frames and derive its
            // render size, so the burned-in overlay lands the right way up.
            dstV.preferredTransform = transform
            if !o.muted, let srcA = try? await asset.loadTracks(withMediaType: .audio).first,
               let dstA = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                try dstA.insertTimeRange(range, of: srcA, at: .zero)
            }
        } catch { throw Failure.failed(error.localizedDescription) }

        if o.speed != 1.0 {
            let scaled = CMTime(seconds: (o.end - o.start) / o.speed, preferredTimescale: 600)
            comp.scaleTimeRange(CMTimeRange(start: .zero, duration: comp.duration), toDuration: scaled)
        }

        guard let session = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality) else {
            throw Failure.noSession
        }

        // Always composited — the watermark makes this unconditional, and the
        // caption rides along in the same canvas so it costs one pass, not two.
        //
        // The overlay is built from the first frame's actual extent rather than
        // from naturalSize + a rotation guess: the filtering handler hands back
        // frames already oriented, so the extent is the truth about where the
        // corner is. It's identical for every frame, hence the cache.
        let cache = OverlayCache()
        let text = o.text, textPos = o.textPos
        session.videoComposition = AVMutableVideoComposition(asset: comp) { request in
            let src = request.sourceImage
            let extent = src.extent
            guard let overlay = cache.image(for: extent.size, make: {
                makeOverlay(renderSize: $0, text: text, pos: textPos)
            }) else {
                request.finish(with: src, context: nil); return
            }
            let placed = overlay.transformed(by: CGAffineTransform(translationX: extent.origin.x,
                                                                  y: extent.origin.y))
            request.finish(with: placed.composited(over: src).cropped(to: extent), context: nil)
        }

        let out = FileManager.default.temporaryDirectory.appendingPathComponent("edit-\(UUID().uuidString).mp4")
        session.outputURL = out
        session.outputFileType = .mp4
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { cont.resume() }
        }
        guard session.status == .completed else {
            throw Failure.failed(session.error?.localizedDescription ?? "Export didn't complete.")
        }
        return out
    }

    // Render the watermark, and the caption when there is one, into a full-frame
    // transparent image (scale 1 so its pixel size matches renderSize), then hand
    // back a CIImage to composite per frame.
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
