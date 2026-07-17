import Foundation
import FirebaseFirestore

// A video released to the signed-in user from manage.everbot.org's Reels tab.
// The producer writes a `commander_videos` doc (see everbot-manage
// Reels.jsx `releasableFrom`); this is the iOS reader's view of that shape.
enum VideoKind: String {
    case reel
    case recording
}

struct AssignedVideo: Identifiable, Equatable {
    let id: String
    let kind: VideoKind
    let title: String
    let videoURL: URL?        // direct https playback URL (preferred)
    let storagePath: String?  // Firebase Storage path, resolved lazily when no videoURL
    let thumbnailURL: URL?
    let durationSeconds: Int?
    let project: String?
    let sourceURL: URL?       // deep link back into manage.everbot.org
    let createdAt: Date?

    // "1:05"-style label, or nil when unknown.
    var durationLabel: String? {
        guard let s = durationSeconds, s > 0 else { return nil }
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // Containers AVPlayer can't decode. Reels composed in the browser (the
    // "Reel · N clips" cards from manage.everbot.org's Reel Editor) come out of
    // Chrome's MediaRecorder as WebM/VP9 when it can't encode H.264 — iOS has no
    // decoder for those, so they'd otherwise open to a black frame that never plays.
    static let unsupportedVideoExtensions: Set<String> = ["webm", "mkv", "ogv", "ogg"]

    // True when the playback source is a container iOS can't decode, judged by file
    // extension. A Firebase download URL keeps the extension in its (percent-encoded)
    // path — .../o/wallcam%2Freels%2Fid.webm?alt=media&token=… — so `pathExtension`
    // still reads "webm" past the query string.
    var isLikelyUnsupportedFormat: Bool {
        let exts = [videoURL?.pathExtension, storagePath.map { ($0 as NSString).pathExtension }]
        return exts.compactMap { $0?.lowercased() }
            .contains { !$0.isEmpty && Self.unsupportedVideoExtensions.contains($0) }
    }

    // Pure parser so the Firestore shape is unit-testable without a live snapshot.
    // Returns nil when the doc has no playable source. Field names match exactly
    // what the Reels "Release to app" action writes.
    static func from(id: String, data: [String: Any]) -> AssignedVideo? {
        let kind = VideoKind(rawValue: (data["kind"] as? String ?? "reel").lowercased()) ?? .reel
        let videoURL = (data["video_url"] as? String).flatMap(URL.init(string:))
        let storagePath = data["storage_path"] as? String
        // Nothing to play without at least one source.
        guard videoURL != nil || (storagePath?.isEmpty == false) else { return nil }

        return AssignedVideo(
            id: id,
            kind: kind,
            title: (data["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Reel",
            videoURL: videoURL,
            storagePath: storagePath,
            thumbnailURL: (data["thumbnail_url"] as? String).flatMap(URL.init(string:)),
            durationSeconds: data["duration_seconds"] as? Int,
            project: data["project"] as? String,
            sourceURL: (data["source_url"] as? String).flatMap(URL.init(string:)),
            createdAt: (data["created_at"] as? Timestamp)?.dateValue()
        )
    }

    // Newest-first. Pure so it is unit-testable.
    static func sortedNewestFirst(_ videos: [AssignedVideo]) -> [AssignedVideo] {
        videos.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    // Optionally narrow to one kind, then sort newest-first. Pure/unit-testable.
    static func filter(_ videos: [AssignedVideo], kind: VideoKind?) -> [AssignedVideo] {
        sortedNewestFirst(kind == nil ? videos : videos.filter { $0.kind == kind })
    }

    // Rotate so `first` leads, preserving order and keeping every clip reachable
    // by paging. The full-screen feed opens at index 0, which a ScrollView shows
    // reliably — so the tapped clip is always the one that plays.
    static func rotated(_ videos: [AssignedVideo], first: AssignedVideo) -> [AssignedVideo] {
        // Match by id, not full equality — the tapped value can differ slightly
        // from the freshly-loaded list (e.g. Timestamp→Date precision), and a
        // full-equality lookup would miss it and fail to rotate.
        guard let i = videos.firstIndex(where: { $0.id == first.id }) else { return videos }
        return Array(videos[i...]) + Array(videos[..<i])
    }
}
