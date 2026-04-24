import XCTest
@testable import MobileCommander

final class CommanderWorkerTests: XCTestCase {

    func testIsOnlineWithRecentHeartbeat() {
        let worker = CommanderWorker(
            id: "w1", hostname: "mac-studio", status: .online,
            tasksCompleted: 10, totalCost: 5.0,
            lastHeartbeat: Date(), activeTaskCount: 1
        )
        XCTAssertTrue(worker.isOnline)
    }

    func testIsOfflineWithOldHeartbeat() {
        let worker = CommanderWorker(
            id: "w1", hostname: "mac-studio", status: .online,
            tasksCompleted: 10, totalCost: 5.0,
            lastHeartbeat: Date().addingTimeInterval(-120), activeTaskCount: 0
        )
        XCTAssertFalse(worker.isOnline)
    }

    func testIsOfflineWithNilHeartbeat() {
        let worker = CommanderWorker(
            id: "w1", hostname: "mac-studio", status: .online,
            tasksCompleted: 10, totalCost: 5.0,
            lastHeartbeat: nil, activeTaskCount: 0
        )
        XCTAssertFalse(worker.isOnline)
    }

    func testIsOnlineWithHeartbeatJustUnderThreshold() {
        let worker = CommanderWorker(
            id: "w1", hostname: "mac-studio", status: .online,
            tasksCompleted: 10, totalCost: 5.0,
            lastHeartbeat: Date().addingTimeInterval(-59), activeTaskCount: 0
        )
        XCTAssertTrue(worker.isOnline)
    }

    func testIsOfflineWithHeartbeatAtExactThreshold() {
        let worker = CommanderWorker(
            id: "w1", hostname: "mac-studio", status: .online,
            tasksCompleted: 10, totalCost: 5.0,
            lastHeartbeat: Date().addingTimeInterval(-60), activeTaskCount: 0
        )
        XCTAssertFalse(worker.isOnline)
    }

    func testWorkerStatusRawValues() {
        XCTAssertEqual(WorkerStatus.online.rawValue, "online")
        XCTAssertEqual(WorkerStatus.offline.rawValue, "offline")
    }

    func testWorkerIdentifiable() {
        let worker = CommanderWorker(
            id: "test-worker", hostname: "test-host", status: .online,
            tasksCompleted: 0, totalCost: 0, lastHeartbeat: nil, activeTaskCount: 0
        )
        XCTAssertEqual(worker.id, "test-worker")
    }
}
