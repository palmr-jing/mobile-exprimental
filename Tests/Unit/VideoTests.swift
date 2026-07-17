import Testing
import Foundation
@testable import MobileCommander

// Verifies the iOS reader parses exactly what manage.everbot.org's Reels
// "Release to app" action writes into commander_videos.
struct VideoTests {
    private func data(_ overrides: [String: Any] = [:]) -> [String: Any] {
        var d: [String: Any] = [
            "kind": "reel",
            "video_url": "https://example.com/reel.mp4",
            "title": "MMA — Person 2",
            "thumbnail_url": "https://example.com/t.jpg",
            "duration_seconds": 65,
            "project": "mobile commander",
            "assigned_emails": ["jamesdcheng@gmail.com"],
        ]
        for (k, v) in overrides { d[k] = v }
        return d
    }

    @Test func parsesReleasedReel() {
        let v = AssignedVideo.from(id: "reel_x", data: data())
        #expect(v?.kind == .reel)
        #expect(v?.title == "MMA — Person 2")
        #expect(v?.videoURL?.absoluteString == "https://example.com/reel.mp4")
        #expect(v?.durationSeconds == 65)
        #expect(v?.durationLabel == "1:05")
        #expect(v?.project == "mobile commander")
    }

    @Test func rejectsDocWithNoPlayableSource() {
        #expect(AssignedVideo.from(id: "x", data: ["kind": "reel", "title": "n"]) == nil)
    }

    @Test func fallsBackToStoragePath() {
        var d = data()
        d.removeValue(forKey: "video_url")
        d["storage_path"] = "reels/x.mp4"
        let v = AssignedVideo.from(id: "x", data: d)
        #expect(v?.videoURL == nil)
        #expect(v?.storagePath == "reels/x.mp4")
    }

    @Test func titleFallsBackWhenEmpty() {
        var d = data()
        d["title"] = ""
        #expect(AssignedVideo.from(id: "x", data: d)?.title == "Reel")
    }

    @Test func sortsNewestFirst() {
        let older = AssignedVideo(id: "a", kind: .reel, title: "a", videoURL: nil,
                                  storagePath: "p", thumbnailURL: nil, durationSeconds: nil,
                                  project: nil, sourceURL: nil, createdAt: Date(timeIntervalSince1970: 100))
        let newer = AssignedVideo(id: "b", kind: .recording, title: "b", videoURL: nil,
                                  storagePath: "p", thumbnailURL: nil, durationSeconds: nil,
                                  project: nil, sourceURL: nil, createdAt: Date(timeIntervalSince1970: 200))
        #expect(AssignedVideo.sortedNewestFirst([older, newer]).first?.id == "b")
        // Kind filter narrows then sorts.
        #expect(AssignedVideo.filter([older, newer], kind: .reel).map(\.id) == ["a"])
        #expect(AssignedVideo.filter([older, newer], kind: nil).map(\.id) == ["b", "a"])
    }

    @Test func rotatedPutsTappedClipFirst() {
        func mk(_ id: String) -> AssignedVideo {
            AssignedVideo(id: id, kind: .reel, title: id, videoURL: nil, storagePath: "p",
                          thumbnailURL: nil, durationSeconds: nil, project: nil, sourceURL: nil, createdAt: nil)
        }
        let vids = ["a", "b", "c", "d"].map(mk)
        // Tapping the 3rd clip opens the feed on it, with the rest reachable.
        #expect(AssignedVideo.rotated(vids, first: vids[2]).map(\.id) == ["c", "d", "a", "b"])
        #expect(AssignedVideo.rotated(vids, first: vids[0]).map(\.id) == ["a", "b", "c", "d"])
    }

    private func mk(videoURL: String? = nil, storagePath: String? = nil) -> AssignedVideo {
        AssignedVideo(id: "x", kind: .reel, title: "t", videoURL: videoURL.flatMap(URL.init(string:)),
                      storagePath: storagePath, thumbnailURL: nil, durationSeconds: nil,
                      project: nil, sourceURL: nil, createdAt: nil)
    }

    @Test func flagsBrowserComposedWebMAsUnsupported() {
        // A Firebase download URL keeps the extension in its percent-encoded path,
        // past the ?alt=media&token=… query — this is the real "Reel · N clips" shape.
        let fb = "https://firebasestorage.googleapis.com/v0/b/app.appspot.com/o/wallcam%2Freels%2Freel-1.webm?alt=media&token=abc"
        #expect(mk(videoURL: fb).isLikelyUnsupportedFormat)
        #expect(mk(videoURL: "https://cdn.example.com/clip.mkv").isLikelyUnsupportedFormat)
        #expect(mk(storagePath: "wallcam/reels/reel-2.webm").isLikelyUnsupportedFormat)
    }

    @Test func doesNotFlagPlayableFormats() {
        let fb = "https://firebasestorage.googleapis.com/v0/b/app.appspot.com/o/wallcam%2Freels%2Freel-1.mp4?alt=media&token=abc"
        #expect(!mk(videoURL: fb).isLikelyUnsupportedFormat)
        #expect(!mk(videoURL: "https://cdn.example.com/reel.mp4").isLikelyUnsupportedFormat)
        #expect(!mk(videoURL: "https://cdn.example.com/reel.mov").isLikelyUnsupportedFormat)
        #expect(!mk(storagePath: "reels/x.mp4").isLikelyUnsupportedFormat)
        // No source at all shouldn't be treated as an unsupported format.
        #expect(!mk().isLikelyUnsupportedFormat)
    }

    @Test func rotatedMatchesByIdEvenWhenOtherFieldsDiffer() {
        func mk(_ id: String, title: String) -> AssignedVideo {
            AssignedVideo(id: id, kind: .reel, title: title, videoURL: nil, storagePath: "p",
                          thumbnailURL: nil, durationSeconds: nil, project: nil, sourceURL: nil, createdAt: nil)
        }
        let list = [mk("a", title: "A"), mk("b", title: "B")]
        // The tapped value is a *stale copy* of b (same id, different title/date) —
        // must still rotate to b. Full-equality matching would miss it. (This is
        // the real bug: Muay Thai wouldn't open because its fields differed.)
        let staleB = mk("b", title: "different")
        #expect(AssignedVideo.rotated(list, first: staleB).map(\.id) == ["b", "a"])
    }
}
