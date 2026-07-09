import XCTest

// Exercises the Videos tab end-to-end against the Firebase emulator: the seed
// (scripts/seed-emulator.mjs) writes a commander_videos reel assigned to
// test@palmr.ai, and the tab should surface it and play it — proving the
// manage.everbot.org "Release to app" → iOS pipeline.
final class VideosUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launchVideos() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITEST", "-FAKE_USER_EMAIL", "test@palmr.ai", "-FAKE_USER_ADMIN", "1"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Videos"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Videos"].tap()
        return app
    }

    func testReleasedReelAppears() {
        let app = launchVideos()
        // The seeded reel card should render, and its title be visible.
        XCTAssertTrue(app.buttons["video-card"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["MMA Night — Fighter Reel"].waitForExistence(timeout: 5))
    }

    func testTapReelOpensPlayer() {
        let app = launchVideos()
        let card = app.buttons["video-card"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        card.tap()
        // The player sheet resolves the URL and mounts an AVKit VideoPlayer.
        XCTAssertTrue(app.otherElements["video-player"].waitForExistence(timeout: 15))
    }
}
