import AVFoundation
import CoreGraphics

// The reel-editor export pipeline, factored out of the view so it can be tested
// without UI: trim to [start, end], optionally change speed, drop audio, and
// burn in the Palmr watermark plus an optional text caption, then write an .mp4.
// Pure inputs → output URL.
//
// The watermark is unconditional. Every clip this app writes leaves with Palmr
// branding burned into its pixels — there is no export path that skips it, so a
// reel shared into chat or saved out stays attributed to Palmr.
//
// The compositing itself lives in `VideoWatermark`, shared with the Released
// tab's "Save to Photos" burn-in so the two brand video identically.
enum ReelExport {
    struct Options {
        var start: Double
        var end: Double
        var speed: Double = 1.0
        var muted: Bool = false
        var text: String = ""
        var textPos: CGPoint = VideoWatermark.defaultTextPos  // normalized, y from top
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
        session.videoComposition = VideoWatermark.videoComposition(for: comp, text: o.text, pos: o.textPos)

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

}
