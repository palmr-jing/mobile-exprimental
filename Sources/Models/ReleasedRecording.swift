import Foundation
import FirebaseFirestore

// A class recording released to the app from manage.everbot.org's Recordings tab.
// The producer's "Release to app" action writes ONE `released_recordings` doc per
// class (doc id = plan_id), grouping all camera angles for that class together.
// This is the iOS reader's view of that shape.
struct ReleasedRecording: Identifiable, Equatable {
    let id: String            // = plan_id (the Firestore doc id)
    let groupKey: String?
    let className: String     // the doc's `class` field (a Swift keyword, hence renamed)
    let device: String?
    let room: String?
    let startsAt: Date?
    let releasedAt: Date?
    let releasedBy: String?
    let angleCount: Int
    let videos: [Angle]

    // One camera angle within a released class. `downloadURL` is a ready-to-play,
    // tokenized Firebase Storage URL written by the producer.
    struct Angle: Identifiable, Equatable {
        let camera: String        // raw: 'front' | 'front-right' | 'realsense'
        let storagePath: String?
        let downloadURL: URL?
        // Poster frame. Absent in the data today (the release pipeline doesn't
        // write one yet); parsed here so it renders automatically once it does.
        var thumbnailURL: URL? = nil

        // Stable within a doc: the producer emits one entry per camera.
        var id: String { camera }

        // True when the source is a container iOS can't decode, judged by file
        // extension — same check (and same shared extension list) the reel player
        // uses. A Firebase download URL keeps the extension in its percent-encoded
        // path, .../o/recordings%2Ffront.webm?alt=media&token=…, so `pathExtension`
        // still reads "webm" past the query string.
        var isLikelyUnsupportedFormat: Bool {
            let exts = [downloadURL?.pathExtension,
                        storagePath.map { ($0 as NSString).pathExtension }]
            return exts.compactMap { $0?.lowercased() }
                .contains { !$0.isEmpty && AssignedVideo.unsupportedVideoExtensions.contains($0) }
        }

        // Human label for the camera. Falls back to a title-cased raw value so an
        // unexpected camera name still renders sensibly.
        var displayName: String {
            switch camera.lowercased() {
            case "front":       return "Front"
            case "front-right": return "Front-right"
            case "realsense":   return "RealSense"
            default:
                return camera.isEmpty ? "Camera"
                    : camera.replacingOccurrences(of: "-", with: " ").capitalized
            }
        }
    }

    // "Jul 10, 2026 · 9:41 AM"-style label from starts_at, or nil when unknown.
    var startsAtLabel: String? {
        guard let startsAt else { return nil }
        return startsAt.formatted(.dateTime.month(.abbreviated).day().year()
            .hour().minute())
    }

    // "everbot-lubancat-2 · Studio A" — device, plus room when present.
    var deviceLabel: String? {
        let parts = [device, room].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // Pure parser so the Firestore shape is unit-testable without a live snapshot.
    // Returns nil only when there is nothing at all to show (no class label AND no
    // playable angle). Field names match exactly what "Release to app" writes.
    static func from(id: String, data: [String: Any]) -> ReleasedRecording? {
        let videos = (data["videos"] as? [[String: Any]] ?? []).map { v in
            Angle(
                camera: (v["camera"] as? String) ?? "",
                storagePath: v["storage_path"] as? String,
                downloadURL: (v["download_url"] as? String).flatMap(URL.init(string:)),
                thumbnailURL: (v["thumbnail_url"] as? String).flatMap(URL.init(string:))
            )
        }
        let className = (data["class"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        // A doc with neither a title nor a single angle isn't worth a card.
        guard className != nil || !videos.isEmpty else { return nil }

        // angle_count is a JSON number: it can decode as Int or Double.
        let angleCount = (data["angle_count"] as? Int)
            ?? (data["angle_count"] as? Double).map(Int.init)
            ?? videos.count

        return ReleasedRecording(
            id: id,
            groupKey: data["group_key"] as? String,
            className: className ?? "Class recording",
            device: data["device"] as? String,
            room: data["room"] as? String,
            startsAt: (data["starts_at"] as? Timestamp)?.dateValue(),
            releasedAt: (data["released_at"] as? Timestamp)?.dateValue(),
            releasedBy: data["released_by"] as? String,
            angleCount: angleCount,
            videos: videos
        )
    }

    // Newest-first by release time, falling back to class start time. Pure so it
    // is unit-testable. Sorted client-side (the collection is one doc per class,
    // so it stays small) — this avoids a composite index and, unlike an
    // `.order(by:)` query, still returns docs that happen to lack `released_at`.
    static func sortedNewestFirst(_ items: [ReleasedRecording]) -> [ReleasedRecording] {
        items.sorted { a, b in
            (a.releasedAt ?? a.startsAt ?? .distantPast)
                > (b.releasedAt ?? b.startsAt ?? .distantPast)
        }
    }
}
