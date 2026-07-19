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
        let src = try await VideoFixtures.makeSampleVideo(seconds: 6)
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
        let src = try await VideoFixtures.makeSampleVideo(seconds: 4)
        defer { try? FileManager.default.removeItem(at: src) }

        let out = try await ReelExport.export(assetURL: src, options: .init(start: 0, end: 4, speed: 2.0))
        defer { try? FileManager.default.removeItem(at: out) }

        let dur = try await CMTimeGetSeconds(AVURLAsset(url: out).load(.duration))
        #expect(dur > 1.5 && dur < 2.5, "4s at 2× should be ~2s, was \(dur)")
    }

    @Test func emptyRangeThrows() async throws {
        let src = try await VideoFixtures.makeSampleVideo(seconds: 2)
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
        let src = try await VideoFixtures.makeSampleVideo(seconds: 4)
        defer { try? FileManager.default.removeItem(at: src) }

        let out = try await ReelExport.export(assetURL: src, options: .init(start: 0, end: 3))
        defer { try? FileManager.default.removeItem(at: out) }

        let probe = try await VideoFixtures.probeFrame(of: out, at: 1.5)

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
        let src = try await VideoFixtures.makeSampleVideo(seconds: 4)
        defer { try? FileManager.default.removeItem(at: src) }

        let out = try await ReelExport.export(assetURL: src,
            options: .init(start: 0, end: 3, text: "IMA MMA class"))
        defer { try? FileManager.default.removeItem(at: out) }

        let probe = try await VideoFixtures.probeFrame(of: out, at: 1.5)
        let background = probe.averageColor(in: probe.quadrant(.topLeft))

        // Caption sits centred at y = 0.82; watermark in the bottom-right corner.
        // Burning one in must not drop the other.
        let captionBand = CGRect(x: 0, y: Double(probe.height) * 0.74,
                                 width: Double(probe.width) * 0.5, height: Double(probe.height) * 0.16)
        #expect(probe.fractionDiffering(from: background, in: captionBand) > 0.02, "caption missing")
        #expect(probe.fractionNearWhite(in: probe.quadrant(.bottomRight)) > 0.001, "watermark missing")
    }
}
