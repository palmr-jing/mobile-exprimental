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

    // The reported bug: opening an angle that iOS can't decode used to leave a
    // permanently black player with no explanation ("click on videos and they
    // don't load or come up"). Opening the WebM angle full-size must now resolve
    // to a visible "can't play" message (the #1063 guard, ported into the
    // full-screen viewer), not a silent black VideoPlayer.
    func testUnsupportedFormatAngleShowsMessage() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Kids BJJ (WebM release)"].waitForExistence(timeout: 20))

        // Scroll the WebM card into view, then open ITS angle (the last play
        // button — the earlier cards' angles are all playable MP4s).
        scrollIntoView(app, app.staticTexts["Kids BJJ (WebM release)"])

        let plays = app.buttons.matching(identifier: "angle-play").allElementsBoundByIndex
        guard let webm = plays.last else { return XCTFail("no angle-play button found") }
        webm.tap()

        // Matched against `.any`: SwiftUI doesn't surface a combined accessibility
        // element as `otherElements` here, so a type-specific query misses it.
        let failed = app.descendants(matching: .any).matching(identifier: "angle-viewer-failed").firstMatch
        XCTAssertTrue(failed.waitForExistence(timeout: 10),
                      "opening an undecodable angle left a silent black player")
    }

    // An angle released with no URL at all should say so in words rather than
    // rendering as an inert black rectangle.
    func testAngleWithNoSourceShowsUnavailable() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Kids BJJ (WebM release)"].waitForExistence(timeout: 20))
        scrollIntoView(app, app.staticTexts["Kids BJJ (WebM release)"])

        let na = app.descendants(matching: .any).matching(identifier: "angle-unavailable").firstMatch
        XCTAssertTrue(na.waitForExistence(timeout: 5),
                      "a source-less angle rendered with no explanation")
    }

    // Every angle tile holding footage carries the Palmr mark, so nothing is
    // presented in the app as unbranded video.
    func testEveryAngleTileIsWatermarked() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["IMA Fit + Tiny Tigers"].waitForExistence(timeout: 20))

        let marks = app.descendants(matching: .any).matching(identifier: "palmr-watermark")
        XCTAssertTrue(marks.firstMatch.waitForExistence(timeout: 5), "no Palmr watermark on the Released tab")

        // One per angle tile of the first card, at minimum.
        let plays = app.buttons.matching(identifier: "angle-play").allElementsBoundByIndex
        XCTAssertGreaterThanOrEqual(marks.count, min(3, plays.count),
                                    "expected a watermark on each angle tile, found \(marks.count)")

        // Pinned to the bottom-trailing corner of the tile it brands (the whole
        // tile is the tap target now), clear of the centred play glyph — so it
        // never covers the control. Checked by position rather than
        // non-intersection: the mark lives inside the tile it brands.
        let mark = marks.element(boundBy: 0).frame
        let tile = plays[0].frame
        XCTAssertGreaterThan(mark.midX, tile.midX, "watermark should sit on the trailing side, off the play glyph")
        XCTAssertGreaterThan(mark.midY, tile.midY, "watermark should sit near the bottom, off the play glyph")
    }

    // The reported bug (#1070): the tab showed "Couldn't load recordings /
    // Missing or insufficient permissions" with no way out. Firestore tears the
    // snapshot listener down on error and the old service guarded on a one-shot
    // `started` flag, so nothing ever re-attached — force-quitting the app was
    // the only recovery. The failure state must now name a cause the user can act
    // on and offer a retry that actually reloads the list.
    func testLoadFailureOffersARecoverableRetry() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITEST", "-MOCK_RELEASED", "-MOCK_RELEASED_ERROR"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Couldn't load recordings"].waitForExistence(timeout: 20),
                      "expected the load-failure state")

        // The copy must point at the fix, not echo Firestore's opaque text.
        XCTAssertFalse(app.staticTexts["Missing or insufficient permissions."].exists,
                       "raw Firestore copy gives the user nothing to act on")

        let retry = app.buttons["empty-action"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5),
                      "the error state stranded the user with no retry")
        retry.tap()

        // Retrying must leave the error state and render the recordings.
        XCTAssertTrue(app.staticTexts["IMA Fit + Tiny Tigers"].waitForExistence(timeout: 20),
                      "Try again didn't reload the recordings")
        XCTAssertFalse(app.staticTexts["Couldn't load recordings"].exists,
                       "error state survived a successful retry")
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

    // The reported ask: tap a thumbnail → the recording opens full-size with a
    // way to download it to the phone.
    func testTappingThumbnailOpensViewerWithDownload() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["IMA Fit + Tiny Tigers"].waitForExistence(timeout: 20))

        app.buttons["angle-play"].firstMatch.tap()

        let download = app.buttons["angle-download"]
        XCTAssertTrue(download.waitForExistence(timeout: 10), "viewer didn't open")
        XCTAssertTrue(download.isEnabled, "download action should be available")
        XCTAssertTrue(app.staticTexts["Front"].exists, "viewer should name the angle")

        app.buttons["angle-viewer-done"].tap()
        XCTAssertTrue(app.buttons["angle-play"].firstMatch.waitForExistence(timeout: 10),
                      "dismissing the viewer should return to the cards")
    }

    // Re-opening must keep working — a stuck modal was the iPad failure mode that
    // left the Videos grid dead to taps.
    func testViewerCanBeReopenedAfterDismiss() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["IMA Fit + Tiny Tigers"].waitForExistence(timeout: 20))

        for _ in 0..<2 {
            app.buttons["angle-play"].firstMatch.tap()
            XCTAssertTrue(app.buttons["angle-download"].waitForExistence(timeout: 10),
                          "viewer didn't open on this pass")
            app.buttons["angle-viewer-done"].tap()
            XCTAssertTrue(app.buttons["angle-play"].firstMatch.waitForExistence(timeout: 10))
        }
    }

    // A WebM release can't be stored by Photos. Saving must say so immediately
    // rather than downloading the whole file and failing at the end — asserted
    // offline, since the guard fires before any network or Photos prompt.
    func testUnsupportedFormatDownloadShowsMessage() {
        let app = launch()
        let webmCard = app.staticTexts["Kids BJJ (WebM release)"]
        XCTAssertTrue(app.staticTexts["IMA Fit + Tiny Tigers"].waitForExistence(timeout: 20))

        // The WebM fixture is the last card; scroll it into view.
        var tries = 0
        while !webmCard.exists && tries < 6 {
            app.swipeUp()
            tries += 1
        }
        XCTAssertTrue(webmCard.waitForExistence(timeout: 10), "WebM fixture card not found")

        app.buttons.matching(identifier: "angle-play").allElementsBoundByIndex.last?.tap()
        XCTAssertTrue(app.buttons["angle-download"].waitForExistence(timeout: 10), "viewer didn't open")
        app.buttons["angle-download"].tap()

        let error = app.staticTexts["angle-download-error"]
        XCTAssertTrue(error.waitForExistence(timeout: 10), "no message for an unsaveable format")
        XCTAssertTrue(error.label.contains("MP4"), "message should say what to ask for: \(error.label)")
    }
}
