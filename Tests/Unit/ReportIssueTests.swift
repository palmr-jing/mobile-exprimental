import Testing
import Foundation
@testable import MobileCommander

// Locks the commander_tasks title/body shape the "Report an issue" flow writes,
// so triage can always tell an app report apart and find the screenshot.
struct ReportIssueTests {
    @Test func titleIsPrefixedAndClippedFromFirstLine() {
        #expect(ReportIssuePresenter.title(from: "Grid overlaps\nmore detail") == "[iOS] Grid overlaps")
        #expect(ReportIssuePresenter.title(from: "   ") == "[iOS] Issue report")
        let long = String(repeating: "x", count: 200)
        let title = ReportIssuePresenter.title(from: long)
        #expect(title.hasPrefix("[iOS] "))
        #expect(title.hasSuffix("…"))
        #expect(title.count < 100)
    }

    @Test func bodyNamesTheTabAndTheAttachedScreenshot() {
        let body = ReportIssuePresenter.body(description: "  it broke  ", tab: "Videos")
        #expect(body.contains("Videos tab"))
        #expect(body.contains("it broke"))
        #expect(body.contains("attachments/screenshot.png"))
    }

    // A tab with no single object in focus stamps just the tab into `context`.
    @Test func tabOnlyContextCarriesTheTab() {
        let map = ReportContext(tab: "Chat").firestoreValue
        #expect(map["tab"] as? String == "Chat")
        #expect(map.count == 1)
    }

    // The recording viewer stamps the exact class it's showing so triage can pin
    // down which released recording (and angle) a report is about.
    @Test func recordingContextCarriesTheClassIdentity() {
        let ctx = ReportContext.recording(Self.sampleRecording,
                                          focusedAngle: Self.sampleRecording.videos[1],
                                          tab: "Released")
        #expect(ctx.tab == "Released")
        #expect(ctx.screen["screen"] == .string("recording"))
        #expect(ctx.screen["className"] == .string("Muay Thai Kickboxing"))
        #expect(ctx.screen["planId"] == .string("plan_42"))
        #expect(ctx.screen["angleCount"] == .int(3))
        #expect(ctx.screen["anglesPresent"] == .strings(["front", "front-right", "realsense"]))
        #expect(ctx.screen["device"] == .string("everbot-lubancat-1"))
        #expect(ctx.screen["room"] == .string("Studio A"))
        #expect(ctx.screen["focusedAngle"] == .string("front-right"))
        #expect(ctx.screen["date"] != nil)
    }

    // firestoreValue flattens to Firestore-safe scalars, and absent optionals are
    // omitted rather than written as null.
    @Test func recordingFirestoreValueFlattensAndOmitsAbsentFields() {
        let bare = ReleasedRecording(
            id: "plan_1", groupKey: nil, className: "Class recording",
            device: nil, room: nil, startsAt: nil, releasedAt: nil, releasedBy: nil,
            angleCount: 1,
            videos: [.init(camera: "front", storagePath: nil, downloadURL: nil)])
        let map = ReportContext.recording(bare, tab: "Released").firestoreValue
        #expect(map["tab"] as? String == "Released")
        #expect(map["planId"] as? String == "plan_1")
        #expect(map["angleCount"] as? Int == 1)
        #expect(map["anglesPresent"] as? [String] == ["front"])
        #expect(map["device"] == nil)        // omitted, not null
        #expect(map["room"] == nil)
        #expect(map["date"] == nil)
        #expect(map["focusedAngle"] == nil)  // no angle in focus
    }

    private static let sampleRecording = ReleasedRecording(
        id: "plan_42", groupKey: "g", className: "Muay Thai Kickboxing",
        device: "everbot-lubancat-1", room: "Studio A",
        startsAt: Date(timeIntervalSince1970: 1_783_593_600),
        releasedAt: nil, releasedBy: nil, angleCount: 3,
        videos: [.init(camera: "front", storagePath: nil, downloadURL: nil),
                 .init(camera: "front-right", storagePath: nil, downloadURL: nil),
                 .init(camera: "realsense", storagePath: nil, downloadURL: nil)])
}
