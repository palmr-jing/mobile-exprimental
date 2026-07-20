import Testing
import Foundation
import FirebaseFirestore
@testable import MobileCommander

// Verifies the iOS reader parses exactly what manage.everbot.org's Recordings
// "Release to app" action writes into `released_recordings` (one doc per class,
// all camera angles grouped).
struct ReleasedRecordingTests {
    private func data(_ overrides: [String: Any] = [:]) -> [String: Any] {
        var d: [String: Any] = [
            "plan_id": "plan_abc",
            "group_key": "grp_1",
            "class": "IMA Fit + Tiny Tigers",
            "room": NSNull(),
            "device": "everbot-lubancat-2",
            "starts_at": Timestamp(date: Date(timeIntervalSince1970: 1_752_144_000)),
            "released_at": Timestamp(date: Date(timeIntervalSince1970: 1_752_150_000)),
            "released_by": "jing@everbot.org",
            "angle_count": 3,
            "source": "recordings-tab",
            "videos": [
                ["camera": "front", "storage_path": "recordings/front.mp4",
                 "download_url": "https://example.com/front.mp4?token=a"],
                ["camera": "front-right", "storage_path": "recordings/fr.mp4",
                 "download_url": "https://example.com/fr.mp4?token=b"],
                ["camera": "realsense", "storage_path": "recordings/rs.mp4",
                 "download_url": "https://example.com/rs.mp4?token=c"],
            ],
        ]
        for (k, v) in overrides { d[k] = v }
        return d
    }

    @Test func parsesReleasedClassWithGroupedAngles() {
        let r = ReleasedRecording.from(id: "plan_abc", data: data())
        #expect(r?.id == "plan_abc")
        #expect(r?.className == "IMA Fit + Tiny Tigers")
        #expect(r?.device == "everbot-lubancat-2")
        #expect(r?.angleCount == 3)
        #expect(r?.videos.count == 3)
        // All three angles stay grouped under the one class.
        #expect(r?.videos.map(\.camera) == ["front", "front-right", "realsense"])
        #expect(r?.videos.first?.downloadURL?.absoluteString == "https://example.com/front.mp4?token=a")
    }

    @Test func mapsCameraLabels() {
        let r = ReleasedRecording.from(id: "x", data: data())
        #expect(r?.videos.map(\.displayName) == ["Front", "Front-right", "RealSense"])
    }

    @Test func nullRoomBecomesNilAndIsOmittedFromLabel() {
        let r = ReleasedRecording.from(id: "x", data: data())
        #expect(r?.room == nil)
        #expect(r?.deviceLabel == "everbot-lubancat-2")
    }

    @Test func roomWhenPresentJoinsDeviceLabel() {
        let r = ReleasedRecording.from(id: "x", data: data(["room": "Studio A"]))
        #expect(r?.room == "Studio A")
        #expect(r?.deviceLabel == "everbot-lubancat-2 · Studio A")
    }

    @Test func angleCountFallsBackToVideoCount() {
        var d = data()
        d.removeValue(forKey: "angle_count")
        #expect(ReleasedRecording.from(id: "x", data: d)?.angleCount == 3)
    }

    @Test func angleCountDecodesFromDouble() {
        #expect(ReleasedRecording.from(id: "x", data: data(["angle_count": 2.0]))?.angleCount == 2)
    }

    @Test func invalidDownloadURLBecomesNilAngle() {
        let d = data(["videos": [["camera": "front", "download_url": ""]]])
        let r = ReleasedRecording.from(id: "x", data: d)
        #expect(r?.videos.first?.downloadURL == nil)
        #expect(r?.videos.first?.storagePath == nil)
    }

    // The poster watcher writes a per-angle `thumbnail_url` into videos[]. The
    // Released grid paints that instead of waiting on the video, so it has to
    // survive the parse (#1071).
    @Test func parsesPerAnglePosterURL() {
        let d = data(["videos": [
            ["camera": "front", "download_url": "https://e.com/front.mp4",
             "thumbnail_url": "https://firebasestorage.googleapis.com/v0/b/x/o/"
                + "released-recordings-thumbs%2Fplan%2Ffront.jpg?alt=media&token=t1"],
            ["camera": "realsense", "download_url": "https://e.com/rs.mp4",
             "thumbnail_url": "https://e.com/rs.jpg"],
        ]])
        let r = ReleasedRecording.from(id: "x", data: d)
        #expect(r?.videos.first?.thumbnailURL?.absoluteString.hasSuffix("token=t1") == true)
        #expect(r?.videos.last?.thumbnailURL?.absoluteString == "https://e.com/rs.jpg")
    }

    // The watcher polls on an interval, so a freshly released class is read
    // before its posters exist. That must parse cleanly (tile falls back to the
    // play glyph), not drop the angle.
    @Test func angleWithNoPosterYetStillParses() {
        let r = ReleasedRecording.from(id: "x", data: data())
        #expect(r?.videos.count == 3)
        #expect(r?.videos.allSatisfy { $0.thumbnailURL == nil } == true)
    }

    // A failed ffmpeg extraction can leave the field present but empty; that is
    // "no poster", not a URL to hand the loader.
    @Test func emptyPosterURLBecomesNil() {
        let d = data(["videos": [["camera": "front", "download_url": "https://e.com/a.mp4",
                                  "thumbnail_url": ""]]])
        #expect(ReleasedRecording.from(id: "x", data: d)?.videos.first?.thumbnailURL == nil)
    }

    @Test func rejectsDocWithNoClassAndNoAngles() {
        #expect(ReleasedRecording.from(id: "x", data: ["source": "x", "videos": []]) == nil)
    }

    @Test func keepsDocWithAnglesButNoClassLabel() {
        let d: [String: Any] = ["videos": [["camera": "front", "download_url": "https://e.com/a.mp4"]]]
        let r = ReleasedRecording.from(id: "x", data: d)
        #expect(r?.className == "Class recording")
        #expect(r?.videos.count == 1)
    }

    // A released angle can be a container iOS has no decoder for (the browser-side
    // release pipeline emits WebM/VP9 when it can't encode H.264). Detecting that
    // by extension is what lets the tile show a reason instead of a black frame.
    @Test func flagsWebMAngleAsUnsupported() {
        let a = ReleasedRecording.Angle(camera: "front", storagePath: nil,
                                        downloadURL: URL(string: "https://e.com/a.webm"))
        #expect(a.isLikelyUnsupportedFormat)
    }

    @Test func treatsMP4AngleAsSupported() {
        let a = ReleasedRecording.Angle(camera: "front", storagePath: "recordings/a.mp4",
                                        downloadURL: URL(string: "https://e.com/a.mp4"))
        #expect(!a.isLikelyUnsupportedFormat)
    }

    // Firebase download URLs percent-encode the path and append a query string;
    // the extension must still be readable through both.
    @Test func readsExtensionThroughFirebaseDownloadURL() {
        let url = URL(string: "https://firebasestorage.googleapis.com/v0/b/x/o/"
                      + "recordings%2Fclass%2Ffront.webm?alt=media&token=abc-123")
        let a = ReleasedRecording.Angle(camera: "front", storagePath: nil, downloadURL: url)
        #expect(a.isLikelyUnsupportedFormat)
    }

    // Falls back to storage_path when the doc has no download_url yet.
    @Test func fallsBackToStoragePathExtension() {
        let a = ReleasedRecording.Angle(camera: "front", storagePath: "recordings/a.mkv",
                                        downloadURL: nil)
        #expect(a.isLikelyUnsupportedFormat)
    }

    @Test func angleWithNoSourceIsNotFlaggedAsUnsupported() {
        let a = ReleasedRecording.Angle(camera: "front", storagePath: nil, downloadURL: nil)
        #expect(!a.isLikelyUnsupportedFormat)
    }

    @Test func sortsNewestFirstByReleasedAtThenStartsAt() {
        func mk(_ id: String, released: TimeInterval?, starts: TimeInterval?) -> ReleasedRecording {
            ReleasedRecording(
                id: id, groupKey: nil, className: id, device: nil, room: nil,
                startsAt: starts.map { Date(timeIntervalSince1970: $0) },
                releasedAt: released.map { Date(timeIntervalSince1970: $0) },
                releasedBy: nil, angleCount: 0, videos: [])
        }
        let a = mk("a", released: 100, starts: 0)
        let b = mk("b", released: 300, starts: 0)
        // Missing released_at falls back to starts_at (here newest of all).
        let c = mk("c", released: nil, starts: 500)
        #expect(ReleasedRecording.sortedNewestFirst([a, b, c]).map(\.id) == ["c", "b", "a"])
    }
}
