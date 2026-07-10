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
}
