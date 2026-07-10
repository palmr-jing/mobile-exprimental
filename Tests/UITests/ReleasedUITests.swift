import XCTest

// Drives the Released tab from -MOCK_RELEASED fixtures (rooted in a TabView like
// production), verifying the cards render and the 3-angle "Send to chat" bundle
// sheet opens — without Firebase.
final class ReleasedUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITEST", "-MOCK_RELEASED"]
        app.launch()
        return app
    }

    func testReleasedShowsCards() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["IMA Fit + Tiny Tigers"].waitForExistence(timeout: 20))
        // Each card exposes a share affordance and a play affordance per angle.
        XCTAssertTrue(app.buttons["recording-share"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["angle-play"].firstMatch.exists)

        // The 3 angles of the first card sit in ONE row: same Y, increasing X, no
        // overlap (geometry, so it holds identically on iPhone + iPad).
        let plays = app.buttons.matching(identifier: "angle-play").allElementsBoundByIndex
        XCTAssertGreaterThanOrEqual(plays.count, 3, "expected 3 angle tiles")
        let row = Array(plays.prefix(3)).map { $0.frame }
        XCTAssertEqual(row[0].midY, row[1].midY, accuracy: 2, "angles not in one row")
        XCTAssertEqual(row[1].midY, row[2].midY, accuracy: 2, "angles not in one row")
        XCTAssertLessThan(row[0].maxX, row[1].midX, "angle 0 overlaps angle 1")
        XCTAssertLessThan(row[1].maxX, row[2].midX, "angle 1 overlaps angle 2")
    }

    func testSendRecordingBundleToChatSheetOpens() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["IMA Fit + Tiny Tigers"].waitForExistence(timeout: 20))

        app.buttons["recording-share"].firstMatch.tap()
        XCTAssertTrue(app.buttons["share-send"].waitForExistence(timeout: 10), "share sheet didn't open")
        XCTAssertTrue(app.staticTexts["Share to chat"].exists)

        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["IMA Fit + Tiny Tigers"].waitForExistence(timeout: 10))
    }
}
