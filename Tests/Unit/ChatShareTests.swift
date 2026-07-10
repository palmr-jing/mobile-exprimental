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
}
