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
}
