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
}
