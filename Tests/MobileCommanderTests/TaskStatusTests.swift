import XCTest
@testable import MobileCommander

final class TaskStatusTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(TaskStatus.allCases.count, 7)
    }

    func testRawValues() {
        XCTAssertEqual(TaskStatus.pending.rawValue, "pending")
        XCTAssertEqual(TaskStatus.claimed.rawValue, "claimed")
        XCTAssertEqual(TaskStatus.running.rawValue, "running")
        XCTAssertEqual(TaskStatus.done.rawValue, "done")
        XCTAssertEqual(TaskStatus.failed.rawValue, "failed")
        XCTAssertEqual(TaskStatus.blocked.rawValue, "blocked")
        XCTAssertEqual(TaskStatus.needsReview.rawValue, "needs_review")
    }

    func testDisplayNames() {
        XCTAssertEqual(TaskStatus.pending.displayName, "Pending")
        XCTAssertEqual(TaskStatus.claimed.displayName, "Claimed")
        XCTAssertEqual(TaskStatus.running.displayName, "Running")
        XCTAssertEqual(TaskStatus.done.displayName, "Done")
        XCTAssertEqual(TaskStatus.failed.displayName, "Failed")
        XCTAssertEqual(TaskStatus.blocked.displayName, "Blocked")
        XCTAssertEqual(TaskStatus.needsReview.displayName, "Review")
    }

    func testIconsAreNotEmpty() {
        for status in TaskStatus.allCases {
            XCTAssertFalse(status.icon.isEmpty, "\(status) should have an icon")
        }
    }

    func testInitFromRawValue() {
        XCTAssertEqual(TaskStatus(rawValue: "needs_review"), .needsReview)
        XCTAssertEqual(TaskStatus(rawValue: "pending"), .pending)
        XCTAssertNil(TaskStatus(rawValue: "invalid"))
    }
}
