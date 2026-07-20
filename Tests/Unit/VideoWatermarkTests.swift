import Testing
import AVFoundation
import UIKit
import CoreMedia
@testable import MobileCommander

// The guarantee behind task #1075: a released class recording saved to the
// user's phone carries Palmr branding in its *pixels*. The display overlay the
// Released tab draws is gone the moment the file leaves the app, so the only
// thing that survives to Photos is what `VideoWatermark.burnIn` writes.
//
// These decode real frames out of a real re-encoded file rather than trusting
// the composition was configured — the bug being fixed was precisely that a
// watermark existed everywhere except in the bytes.
struct VideoWatermarkTests {

    @Test func burnsTheMarkIntoTheSavedFilesPixels() async throws {
        let src = try await VideoFixtures.makeSampleVideo(seconds: 3)
        defer { try? FileManager.default.removeItem(at: src) }

        let out = try await VideoWatermark.burnIn(into: src, named: "IMA-Fit-front.mp4")
        defer { try? FileManager.default.removeItem(at: out.deletingLastPathComponent()) }

        let probe = try await VideoFixtures.probeFrame(of: out, at: 1.5)
        // Each generated frame is one flat hue, so the untouched top-left tells
        // us this frame's background without hardcoding a colour.
        let background = probe.averageColor(in: probe.quadrant(.topLeft))

        let branded = probe.fractionDiffering(from: background, in: probe.quadrant(.bottomRight))
        #expect(branded > 0.01,
                "saved frame has no watermark in the bottom-right (\(branded * 100)% of pixels differ)")
        // The mark is drawn white, which a fully saturated source hue never is.
        #expect(probe.fractionNearWhite(in: probe.quadrant(.bottomRight)) > 0.001,
                "no white Palmr mark burned into the corner")

        // Nothing may cover the class the user is actually watching.
        #expect(probe.fractionDiffering(from: background, in: probe.quadrant(.topLeft)) < 0.01,
                "the rest of the frame should be untouched")
    }

    @Test func brandsTheWholeRecordingNotJustTheOpeningFrames() async throws {
        // A burn-in that only covered the first seconds would still pass a
        // single-frame check while leaving most of the class unbranded.
        let src = try await VideoFixtures.makeSampleVideo(seconds: 5)
        defer { try? FileManager.default.removeItem(at: src) }

        let out = try await VideoWatermark.burnIn(into: src, named: "clip.mp4")
        defer { try? FileManager.default.removeItem(at: out.deletingLastPathComponent()) }

        for t in [0.5, 2.5, 4.5] {
            let probe = try await VideoFixtures.probeFrame(of: out, at: t)
            #expect(probe.fractionNearWhite(in: probe.quadrant(.bottomRight)) > 0.001,
                    "frame at \(t)s is missing the watermark")
        }
    }

    @Test func keepsTheFullRecordingNotJustASegment() async throws {
        let src = try await VideoFixtures.makeSampleVideo(seconds: 4)
        defer { try? FileManager.default.removeItem(at: src) }

        let out = try await VideoWatermark.burnIn(into: src, named: "clip.mp4")
        defer { try? FileManager.default.removeItem(at: out.deletingLastPathComponent()) }

        let dur = try await CMTimeGetSeconds(AVURLAsset(url: out).load(.duration))
        #expect(dur > 3.5 && dur < 4.5, "watermarking must not trim the recording, got \(dur)s")
    }

    // A class recording is worth watching for what was said in it. The reel
    // exporter can drop audio on purpose; this path never may.
    @Test func carriesTheClassAudioAcross() async throws {
        let src = try await VideoFixtures.makeSampleVideoWithAudio(seconds: 3)
        defer { try? FileManager.default.removeItem(at: src) }
        // Guard the fixture itself, so a silent source can't make this vacuous.
        #expect(try await !AVURLAsset(url: src).loadTracks(withMediaType: .audio).isEmpty,
                "fixture should have produced an audio track")

        let out = try await VideoWatermark.burnIn(into: src, named: "clip.mp4")
        defer { try? FileManager.default.removeItem(at: out.deletingLastPathComponent()) }

        let audio = try await AVURLAsset(url: out).loadTracks(withMediaType: .audio)
        #expect(!audio.isEmpty, "watermarking dropped the recording's audio track")
    }

    @Test func namesTheOutputMp4BecauseItAlwaysReencodesToMp4() {
        // Photos types the asset from the extension, so carrying a source .mov
        // through onto an H.264/MP4 re-encode would mislabel it.
        #expect(VideoWatermark.mp4Name("IMA-Fit-front.mov") == "IMA-Fit-front.mp4")
        #expect(VideoWatermark.mp4Name("clip.mp4") == "clip.mp4")
        #expect(VideoWatermark.mp4Name("clip") == "clip.mp4")
        #expect(VideoWatermark.mp4Name("") == "video.mp4")
    }

    @Test func aFileWithNoVideoTrackFailsInsteadOfWritingSomethingUnbranded() async throws {
        let bogus = FileManager.default.temporaryDirectory
            .appendingPathComponent("not-a-video-\(UUID().uuidString).mp4")
        try Data("this is not a video".utf8).write(to: bogus)
        defer { try? FileManager.default.removeItem(at: bogus) }

        await #expect(throws: VideoWatermark.Failure.noVideoTrack) {
            _ = try await VideoWatermark.burnIn(into: bogus, named: "clip.mp4")
        }
    }
}
