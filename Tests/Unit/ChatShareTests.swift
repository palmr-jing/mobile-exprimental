import Testing
import Foundation
@testable import MobileCommander

// The share-to-chat message must HOLD the playable URL + poster as metadata, so
// a message alone lets @emma fetch the clip without re-querying commander_videos.
// Locks the wire shape ChatService.sendReel writes (see reelMessagePayload).
struct ChatShareTests {
    private func reel() -> AssignedVideo {
        AssignedVideo(
            id: "rid", kind: .reel, title: "Muay Thai Kickboxing",
            videoURL: URL(string: "https://storage.googleapis.com/x/reel.mp4"),
            storagePath: "reels/rid.mp4",
            thumbnailURL: URL(string: "https://storage.googleapis.com/x/reel.jpg"),
            durationSeconds: 30, project: "mobile commander", sourceURL: nil, createdAt: nil
        )
    }

    @Test func payloadHoldsUrlThumbnailAndProvenance() {
        let p = ChatService.reelMessagePayload(video: reel(), caption: "check this", mentionEmma: false,
                                               authorUid: "u1", authorName: "James", authorEmail: "j@x.com")
        #expect(p["type"] as? String == "video")
        #expect(p["text"] as? String == "check this")
        #expect(p["authorEmail"] as? String == "j@x.com")
        let a = p["attachment"] as? [String: Any]
        #expect(a?["url"] as? String == "https://storage.googleapis.com/x/reel.mp4")
        #expect(a?["thumbnail_url"] as? String == "https://storage.googleapis.com/x/reel.jpg")
        #expect(a?["contentType"] as? String == "video/mp4")
        #expect(a?["video_id"] as? String == "rid")
        #expect(a?["source"] as? String == "commander_videos")
        // Not addressed to Emma unless asked.
        #expect(p["mentionsEmma"] == nil)
    }

    @Test func emptyCaptionFallsBackToTitle() {
        let p = ChatService.reelMessagePayload(video: reel(), caption: "   ", mentionEmma: false,
                                               authorUid: "u", authorName: "n", authorEmail: "e")
        #expect(p["text"] as? String == "Muay Thai Kickboxing")
    }

    @Test func mentionEmmaTagsAndPrefixesCaption() {
        let p = ChatService.reelMessagePayload(video: reel(), caption: "what's this move?", mentionEmma: true,
                                               authorUid: "u", authorName: "n", authorEmail: "e")
        #expect(p["mentionsEmma"] as? Bool == true)
        #expect(p["emmaStatus"] as? String == "pending")
        let text = p["text"] as? String
        #expect(text?.contains("@emma") == true)
        #expect(text?.contains("what's this move?") == true)
    }

    @Test func mentionEmmaEmptyCaptionIsJustTheHandle() {
        let p = ChatService.reelMessagePayload(video: reel(), caption: "", mentionEmma: true,
                                               authorUid: "u", authorName: "n", authorEmail: "e")
        #expect(p["text"] as? String == "@emma")
    }

    @Test func alreadyMentionsEmmaIsNotDoublePrefixed() {
        let p = ChatService.reelMessagePayload(video: reel(), caption: "@emma break this down", mentionEmma: true,
                                               authorUid: "u", authorName: "n", authorEmail: "e")
        #expect(p["text"] as? String == "@emma break this down")
    }

    // A recording with no direct URL still shares — it carries the storage path so
    // Emma can resolve playback, and the poster stays present.
    @Test func recordingWithoutDirectUrlStillCarriesStoragePath() {
        let rec = AssignedVideo(id: "x", kind: .recording, title: "Open Mat", videoURL: nil,
                                storagePath: "recordings/x.mp4",
                                thumbnailURL: URL(string: "https://x/y.jpg"),
                                durationSeconds: nil, project: nil, sourceURL: nil, createdAt: nil)
        let a = ChatService.reelMessagePayload(video: rec, caption: "", mentionEmma: false,
                                               authorUid: "u", authorName: "n", authorEmail: "e")["attachment"] as? [String: Any]
        #expect(a?["url"] as? String == "")
        #expect(a?["storage_path"] as? String == "recordings/x.mp4")
        #expect(a?["thumbnail_url"] as? String == "https://x/y.jpg")
    }

    // ── Class recording bundle (all 3 angles in one message) ────────────────────

    private func classRecording() -> ReleasedRecording {
        func angle(_ cam: String, _ file: String) -> ReleasedRecording.Angle {
            .init(camera: cam, storagePath: "recordings/\(file)",
                  downloadURL: URL(string: "https://x/\(file)"),
                  thumbnailURL: URL(string: "https://x/\(file).jpg"))
        }
        return ReleasedRecording(
            id: "plan_1", groupKey: "g", className: "Muay Thai Kickboxing",
            device: "everbot-lubancat-2", room: nil, startsAt: nil, releasedAt: nil,
            releasedBy: nil, angleCount: 3,
            videos: [angle("front", "front.mp4"), angle("front-right", "fr.mp4"), angle("realsense", "rs.mp4")])
    }

    @Test func recordingBundleHoldsEveryAngleAndFrontPrimary() {
        let p = ChatService.recordingMessagePayload(recording: classRecording(), caption: "check footwork",
                                                    mentionEmma: false, authorUid: "u", authorName: "n", authorEmail: "e")
        #expect(p["type"] as? String == "video")
        #expect(p["text"] as? String == "check footwork")
        // Primary attachment = front angle so single-attachment renderers still play.
        let a = p["attachment"] as? [String: Any]
        #expect(a?["url"] as? String == "https://x/front.mp4")
        #expect(a?["name"] as? String == "Muay Thai Kickboxing")
        // recording holds ALL three angles.
        let rec = p["recording"] as? [String: Any]
        #expect(rec?["class"] as? String == "Muay Thai Kickboxing")
        let angles = rec?["angles"] as? [[String: Any]]
        #expect(angles?.count == 3)
        #expect(angles?.map { $0["camera"] as? String ?? "" } == ["front", "front-right", "realsense"])
        #expect(angles?[2]["url"] as? String == "https://x/rs.mp4")
        #expect(p["mentionsEmma"] == nil)
    }

    @Test func recordingBundleEmptyCaptionFallsBackToClassName() {
        let p = ChatService.recordingMessagePayload(recording: classRecording(), caption: "  ",
                                                    mentionEmma: false, authorUid: "u", authorName: "n", authorEmail: "e")
        #expect(p["text"] as? String == "Muay Thai Kickboxing")
    }

    @Test func recordingBundleMentionEmmaTags() {
        let p = ChatService.recordingMessagePayload(recording: classRecording(), caption: "what's this?",
                                                    mentionEmma: true, authorUid: "u", authorName: "n", authorEmail: "e")
        #expect(p["mentionsEmma"] as? Bool == true)
        #expect(p["emmaStatus"] as? String == "pending")
        #expect((p["text"] as? String)?.contains("@emma") == true)
    }
}
