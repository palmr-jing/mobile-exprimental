import Testing
import AVFoundation
import UIKit
import CoreMedia
@testable import MobileCommander

// End-to-end test of the reel-editor export workflow: generate a real video,
// run it through ReelExport (trim / text / speed / mute), and assert the output
// is a valid, correctly-trimmed clip. Hermetic — no Firebase, no UI.
struct ReelExportTests {

    @Test func trimsToTheSelectedRangeAndBurnsInText() async throws {
        let src = try await Self.makeSampleVideo(seconds: 6)
        defer { try? FileManager.default.removeItem(at: src) }

        let out = try await ReelExport.export(assetURL: src,
            options: .init(start: 1.0, end: 4.0, text: "IMA MMA class"))
        defer { try? FileManager.default.removeItem(at: out) }

        #expect(FileManager.default.fileExists(atPath: out.path))
        let asset = AVURLAsset(url: out)
        let dur = try await CMTimeGetSeconds(asset.load(.duration))
        #expect(dur > 2.5 && dur < 3.5, "trimmed clip should be ~3s, was \(dur)")
        let tracks = try await asset.loadTracks(withMediaType: .video)
        #expect(!tracks.isEmpty, "export should contain a video track")
    }

    @Test func speedTwoXHalvesTheDuration() async throws {
        let src = try await Self.makeSampleVideo(seconds: 4)
        defer { try? FileManager.default.removeItem(at: src) }

        let out = try await ReelExport.export(assetURL: src, options: .init(start: 0, end: 4, speed: 2.0))
        defer { try? FileManager.default.removeItem(at: out) }

        let dur = try await CMTimeGetSeconds(AVURLAsset(url: out).load(.duration))
        #expect(dur > 1.5 && dur < 2.5, "4s at 2× should be ~2s, was \(dur)")
    }

    @Test func emptyRangeThrows() async throws {
        let src = try await Self.makeSampleVideo(seconds: 2)
        defer { try? FileManager.default.removeItem(at: src) }
        await #expect(throws: ReelExport.Failure.self) {
            _ = try await ReelExport.export(assetURL: src, options: .init(start: 2, end: 2))
        }
    }

    // The guarantee the Palmr watermark work rests on: an export with no caption,
    // no speed change, nothing — the plainest possible path — still comes out of
    // the pipeline with branding burned into its pixels. Decodes a real frame from
    // the written file rather than trusting the composition was configured.
    @Test func everyExportCarriesTheWatermarkEvenWithNoCaption() async throws {
        let src = try await Self.makeSampleVideo(seconds: 4)
        defer { try? FileManager.default.removeItem(at: src) }

        let out = try await ReelExport.export(assetURL: src, options: .init(start: 0, end: 3))
        defer { try? FileManager.default.removeItem(at: out) }

        let probe = try await Self.probeFrame(of: out, at: 1.5)

        // Each generated frame is a single flat hue, so the untouched top-left
        // tells us what this frame's background is without hardcoding a colour.
        let background = probe.averageColor(in: probe.quadrant(.topLeft))

        // The translucent plate shifts the corner away from the flat background...
        let branded = probe.fractionDiffering(from: background, in: probe.quadrant(.bottomRight))
        #expect(branded > 0.01,
                "exported frame has no watermark in the bottom-right (\(branded * 100)% of pixels differ)")

        // ...and the mark itself is white, which a saturated source hue never is.
        let mark = probe.fractionNearWhite(in: probe.quadrant(.bottomRight))
        #expect(mark > 0.001, "no white Palmr mark in the corner (\(mark * 100)% of pixels)")

        let clean = probe.fractionDiffering(from: background, in: probe.quadrant(.topLeft))
        #expect(clean < 0.01, "the rest of the frame should be untouched, \(clean * 100)% differs")
        #expect(probe.fractionNearWhite(in: probe.quadrant(.topLeft)) < 0.001,
                "nothing should be drawn over the top-left of the frame")
    }

    @Test func watermarkAndCaptionCoexist() async throws {
        let src = try await Self.makeSampleVideo(seconds: 4)
        defer { try? FileManager.default.removeItem(at: src) }

        let out = try await ReelExport.export(assetURL: src,
            options: .init(start: 0, end: 3, text: "IMA MMA class"))
        defer { try? FileManager.default.removeItem(at: out) }

        let probe = try await Self.probeFrame(of: out, at: 1.5)
        let background = probe.averageColor(in: probe.quadrant(.topLeft))

        // Caption sits centred at y = 0.82; watermark in the bottom-right corner.
        // Burning one in must not drop the other.
        let captionBand = CGRect(x: 0, y: Double(probe.height) * 0.74,
                                 width: Double(probe.width) * 0.5, height: Double(probe.height) * 0.16)
        #expect(probe.fractionDiffering(from: background, in: captionBand) > 0.02, "caption missing")
        #expect(probe.fractionNearWhite(in: probe.quadrant(.bottomRight)) > 0.001, "watermark missing")
    }

    // MARK: - decode a frame out of an exported file

    private static func probeFrame(of url: URL, at seconds: Double) async throws -> Pixels.Probe {
        let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        gen.appliesPreferredTrackTransform = true
        gen.requestedTimeToleranceBefore = .zero
        gen.requestedTimeToleranceAfter = .zero
        let cg = try await gen.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
        return try Pixels.probe(cg)
    }

    // MARK: - generate a small H.264 clip for the test

    private static func makeSampleVideo(seconds: Double, fps: Int = 30,
                                        size: CGSize = CGSize(width: 320, height: 568)) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("src-\(UUID().uuidString).mp4")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height,
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height,
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let total = Int(seconds * Double(fps))
        for i in 0..<total {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 500_000) }
            let pb = makePixelBuffer(size: size, frame: i)
            adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: CMTimeScale(fps)))
        }
        input.markAsFinished()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            writer.finishWriting { cont.resume() }
        }
        return url
    }

    private static func makePixelBuffer(size: CGSize, frame: Int) -> CVPixelBuffer {
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(nil, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, nil, &pb)
        let buf = pb!
        CVPixelBufferLockBaseAddress(buf, [])
        let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf),
                            width: Int(size.width), height: Int(size.height),
                            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buf),
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
        ctx.setFillColor(UIColor(hue: CGFloat(frame % 60) / 60.0, saturation: 1, brightness: 1, alpha: 1).cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        CVPixelBufferUnlockBaseAddress(buf, [])
        return buf
    }
}
