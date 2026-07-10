import XCTest

// Drives the Videos tab from deterministic mock fixtures (-MOCK_VIDEOS), so the
// grid + tap→play routing is verified without Firebase. Catches the "tap one
// reel, a different one opens" class of bug.
final class VideosUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launchMockVideos() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITEST", "-MOCK_VIDEOS"]
        app.launch()
        return app
    }

    func testGridShowsReels() {
        let app = launchMockVideos()
        XCTAssertTrue(app.staticTexts["Muay Thai Kickboxing"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["video-card"].firstMatch.exists)
    }

    func testTappingEachReelOpensThatReel() {
        let app = launchMockVideos()
        // Open several reels — including the first (Muay Thai) and a middle one
        // (BJJ) — and confirm each opens the reel that was tapped, not another.
        for name in ["Muay Thai Kickboxing", "Brazilian Jiu Jitsu", "Open Mat Rolls"] {
            let card = app.staticTexts[name]
            XCTAssertTrue(card.waitForExistence(timeout: 20), "grid missing \(name)")
            card.tap()
            let title = app.staticTexts["reel-title"].firstMatch
            XCTAssertTrue(title.waitForExistence(timeout: 10), "feed didn't open for \(name)")
            XCTAssertEqual(title.label, name, "Tapping \(name) opened a different reel")
            app.buttons["reel-close"].tap()
            XCTAssertTrue(card.waitForExistence(timeout: 10), "didn't return to grid after \(name)")
        }
    }

    // Reproduces the reported bug: open a reel, close it, then open a DIFFERENT
    // reel. The second open must present the reel you tapped — not silently fail.
    func testOpenCloseThenOpenAnother() {
        let app = launchMockVideos()
        func open(_ name: String) {
            let card = app.staticTexts[name]
            XCTAssertTrue(card.waitForExistence(timeout: 20), "grid missing \(name)")
            card.tap()
            let title = app.staticTexts["reel-title"].firstMatch
            XCTAssertTrue(title.waitForExistence(timeout: 10), "feed didn't open for \(name)")
            XCTAssertEqual(title.label, name, "opened a different reel than \(name)")
        }
        func close() {
            app.buttons["reel-close"].tap()
            // The cover must fully tear down — a lingering player/overlay is the
            // signature of an orphaned presentation that would eat grid taps.
            XCTAssertTrue(app.staticTexts["reel-title"].firstMatch.waitForNonExistence(timeout: 10),
                          "feed overlay didn't dismiss")
        }
        // BJJ first (the reported order), close, then Muay Thai must still open.
        open("Brazilian Jiu Jitsu"); close()
        open("Muay Thai Kickboxing"); close()
        // And once more, reversed, to be sure it isn't order-specific.
        open("Muay Thai Kickboxing"); close()
        open("Brazilian Jiu Jitsu"); close()
    }

    // The "Send to chat" affordance opens a share sheet with a destination picker
    // and a Send button — the reel can be posted into chat from the feed.
    func testShareReelToChatOpensSheet() {
        let app = launchMockVideos()
        let card = app.staticTexts["Muay Thai Kickboxing"]
        XCTAssertTrue(card.waitForExistence(timeout: 20))
        card.tap()

        // The paging feed renders several pages' overlays, so match the first.
        let share = app.buttons["reel-share"].firstMatch
        XCTAssertTrue(share.waitForExistence(timeout: 10), "no Send-to-chat button on the feed")
        share.tap()

        XCTAssertTrue(app.staticTexts["Share to chat"].waitForExistence(timeout: 10), "share sheet didn't open")
        XCTAssertTrue(app.buttons["share-send"].exists, "share sheet missing Send")

        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["reel-title"].waitForExistence(timeout: 10), "didn't return to the feed")
    }
}
