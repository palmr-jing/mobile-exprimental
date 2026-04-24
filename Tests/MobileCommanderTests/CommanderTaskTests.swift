import XCTest
@testable import MobileCommander

final class CommanderTaskTests: XCTestCase {

    private func makeTask(
        status: TaskStatus = .pending,
        reviewStatus: String? = nil
    ) -> CommanderTask {
        CommanderTask(
            id: "test-id",
            numId: 1,
            project: "test-project",
            path: "~/repos/test",
            task: "Test task",
            description: "A test task",
            status: status,
            priority: 5,
            dependsOn: [],
            allowParallel: false,
            reviewStatus: reviewStatus
        )
    }

    func testEffectiveStatusReturnsDoneWhenNoReviewStatus() {
        let task = makeTask(status: .done, reviewStatus: nil)
        XCTAssertEqual(task.effectiveStatus, .done)
    }

    func testEffectiveStatusReturnsNeedsReviewWhenDoneWithReview() {
        let task = makeTask(status: .done, reviewStatus: "needs_review")
        XCTAssertEqual(task.effectiveStatus, .needsReview)
    }

    func testEffectiveStatusReturnsDoneWithApprovedReview() {
        let task = makeTask(status: .done, reviewStatus: "approved")
        XCTAssertEqual(task.effectiveStatus, .done)
    }

    func testEffectiveStatusReturnsRunningEvenWithReviewStatus() {
        let task = makeTask(status: .running, reviewStatus: "needs_review")
        XCTAssertEqual(task.effectiveStatus, .running)
    }

    func testEffectiveStatusReturnsPendingRegardlessOfReview() {
        let task = makeTask(status: .pending, reviewStatus: "needs_review")
        XCTAssertEqual(task.effectiveStatus, .pending)
    }

    func testEffectiveStatusReturnsFailedRegardlessOfReview() {
        let task = makeTask(status: .failed, reviewStatus: "needs_review")
        XCTAssertEqual(task.effectiveStatus, .failed)
    }

    func testTaskIdentifiable() {
        let task = makeTask()
        XCTAssertEqual(task.id, "test-id")
    }

    func testOptionalFieldsDefaultToNil() {
        let task = makeTask()
        XCTAssertNil(task.assignedWorker)
        XCTAssertNil(task.claimedBy)
        XCTAssertNil(task.createdBy)
        XCTAssertNil(task.costUsd)
        XCTAssertNil(task.durationMs)
        XCTAssertNil(task.exitCode)
        XCTAssertNil(task.error)
        XCTAssertNil(task.resultText)
        XCTAssertNil(task.followUp)
        XCTAssertNil(task.createdAt)
        XCTAssertNil(task.completedAt)
    }
}
