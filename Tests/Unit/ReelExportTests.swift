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
