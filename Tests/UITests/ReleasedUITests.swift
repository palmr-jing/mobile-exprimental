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

    // Bounded scroll — an unbounded `while !isHittable { swipeUp() }` hangs the
    // whole suite if the element never becomes hittable.
    private func scrollIntoView(_ app: XCUIApplication, _ element: XCUIElement,
                                maxSwipes: Int = 6) {
        for _ in 0..<maxSwipes where !element.isHittable { app.swipeUp() }
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

    // The reported bug: tapping an angle that iOS can't decode used to leave a
    // permanently black tile with no explanation ("click on videos and they don't
    // load or come up"). The tap must now resolve to a visible message.
    func testUnsupportedFormatAngleShowsMessage() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Unsupported Format Class"].waitForExistence(timeout: 20))

        // Scroll the failing card into view, then tap ITS play button (the last
        // one on screen — the earlier cards' angles are all playable MP4s).
        scrollIntoView(app, app.staticTexts["Unsupported Format Class"])

        let plays = app.buttons.matching(identifier: "angle-play").allElementsBoundByIndex
        guard let webm = plays.last else { return XCTFail("no angle-play button found") }
        webm.tap()

        // Matched against `.any`: SwiftUI doesn't surface a combined accessibility
        // element as `otherElements` here, so a type-specific query misses it.
        let failed = app.descendants(matching: .any).matching(identifier: "angle-failed").firstMatch
        XCTAssertTrue(failed.waitForExistence(timeout: 10),
                      "tapping an undecodable angle left a silent black tile")
    }

    // An angle released with no URL at all should say so in words rather than
    // rendering as an inert black rectangle.
    func testAngleWithNoSourceShowsUnavailable() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Unsupported Format Class"].waitForExistence(timeout: 20))
        scrollIntoView(app, app.staticTexts["Unsupported Format Class"])

        let na = app.descendants(matching: .any).matching(identifier: "angle-unavailable").firstMatch
        XCTAssertTrue(na.waitForExistence(timeout: 5),
                      "a source-less angle rendered with no explanation")
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
