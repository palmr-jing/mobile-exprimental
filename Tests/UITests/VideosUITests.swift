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

    func testTappingAReelOpensThatReel() {
        let app = launchMockVideos()
        // Tap a reel that is NOT first in the grid.
        let bjj = app.staticTexts["Brazilian Jiu Jitsu"]
        XCTAssertTrue(bjj.waitForExistence(timeout: 20))
        bjj.tap()
        // The full-screen feed must open on the reel we tapped, not another.
        let title = app.staticTexts["reel-title"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "Brazilian Jiu Jitsu", "Tapping a reel opened a different one")
    }
}
