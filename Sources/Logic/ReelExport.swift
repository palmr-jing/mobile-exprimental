import AVFoundation
import UIKit
import CoreImage

// The reel-editor export pipeline, factored out of the view so it can be tested
// without UI: trim to [start, end], optionally change speed, drop audio, and
// burn in a text caption, then write an .mp4. Pure inputs → output URL.
//
// Text is burned in with a Core Image per-frame handler rather than
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
            dstV.preferredTransform = transform   // keep orientation for the no-overlay path
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

        if !o.text.isEmpty {
            let natural = (try? await srcV.load(.naturalSize)) ?? CGSize(width: 720, height: 1280)
            let rotated = abs(transform.b) == 1 && abs(transform.c) == 1
            let renderSize = rotated ? CGSize(width: natural.height, height: natural.width) : natural
            if let overlay = makeTextOverlay(text: o.text, renderSize: renderSize, pos: o.textPos) {
                session.videoComposition = AVMutableVideoComposition(asset: comp) { request in
                    let out = overlay.composited(over: request.sourceImage).cropped(to: request.sourceImage.extent)
                    request.finish(with: out, context: nil)
                }
            }
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

    // Render the caption into a full-frame transparent image (scale 1 so its pixel
    // size matches renderSize), then hand back a CIImage to composite per frame.
    private static func makeTextOverlay(text: String, renderSize: CGSize, pos: CGPoint) -> CIImage? {
        guard renderSize.width > 0, renderSize.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let img = UIGraphicsImageRenderer(size: renderSize, format: format).image { _ in
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
        return CIImage(image: img)
    }
}
