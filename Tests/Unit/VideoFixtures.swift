import Testing
import AVFoundation
import UIKit
import CoreMedia

// Real H.264 clips generated on the fly, plus frame readback, shared by every
// suite that needs to assert on video the app actually wrote (ReelExportTests,
// VideoWatermarkTests). Generating a file beats checking one in: the assertions
// are about pixels in a decoded frame, so the source has to be a genuine
// encode, and a fixture in the repo would be a binary nobody can review.
enum VideoFixtures {

    /// Decode the frame at `seconds` out of a written file, oriented as a player
    /// would show it, and hand back an RGBA probe.
    static func probeFrame(of url: URL, at seconds: Double) async throws -> Pixels.Probe {
        let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        gen.appliesPreferredTrackTransform = true
        gen.requestedTimeToleranceBefore = .zero
        gen.requestedTimeToleranceAfter = .zero
        let cg = try await gen.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
        return try Pixels.probe(cg)
    }

    /// A silent clip whose every frame is one flat, fully saturated hue — so any
    /// pixel that isn't that hue is something the code under test drew.
    static func makeSampleVideo(seconds: Double, fps: Int = 30,
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

    /// The same clip with a real (silent) audio track, for asserting that a
    /// re-encode carries audio across instead of quietly dropping it.
    ///
    /// The audio is written with AVAudioFile and merged in with a composition
    /// rather than hand-rolling CMSampleBuffers into the same AVAssetWriter —
    /// the hand-rolled version crashed the test host, and a fixture that can
    /// take down the process is worse than no fixture.
    static func makeSampleVideoWithAudio(seconds: Double,
                                         size: CGSize = CGSize(width: 320, height: 568)) async throws -> URL {
        let videoURL = try await makeSampleVideo(seconds: seconds, size: size)
        defer { try? FileManager.default.removeItem(at: videoURL) }
        let audioURL = try makeSilentAudio(seconds: seconds)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let comp = AVMutableComposition()
        let videoAsset = AVURLAsset(url: videoURL), audioAsset = AVURLAsset(url: audioURL)
        guard let srcV = try await videoAsset.loadTracks(withMediaType: .video).first,
              let dstV = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let srcA = try await audioAsset.loadTracks(withMediaType: .audio).first,
              let dstA = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw FixtureError.couldNotBuild }
        let vRange = try await srcV.load(.timeRange)
        try dstV.insertTimeRange(vRange, of: srcV, at: .zero)
        let aRange = try await srcA.load(.timeRange)
        try dstA.insertTimeRange(vRange.intersection(aRange), of: srcA, at: .zero)

        let out = FileManager.default.temporaryDirectory.appendingPathComponent("srcav-\(UUID().uuidString).mp4")
        guard let session = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality)
        else { throw FixtureError.couldNotBuild }
        session.outputURL = out
        session.outputFileType = .mp4
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { cont.resume() }
        }
        guard session.status == .completed else { throw FixtureError.couldNotBuild }
        return out
    }

    enum FixtureError: Error { case couldNotBuild }

    /// `seconds` of silence as an .m4a. Zero-filled PCM — the content is
    /// irrelevant, only that a genuine audio track exists to be carried across.
    private static func makeSilentAudio(seconds: Double) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sil-\(UUID().uuidString).m4a")
        let sampleRate = 44_100.0
        let file = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
        ])
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(sampleRate * seconds))
        else { throw FixtureError.couldNotBuild }
        buffer.frameLength = buffer.frameCapacity   // freshly allocated == silence
        try file.write(from: buffer)
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
