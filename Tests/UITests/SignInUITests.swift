import XCTest

// Drives the real app with the fake-auth seam so we reach the signed-in UI
// without Google. Runs against the Firebase emulator (-UITEST).
final class SignInUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launchApp(admin: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITEST", "-FAKE_USER_EMAIL", "test@palmr.ai", "-FAKE_USER_ADMIN", admin ? "1" : "0"]
        app.launch()
        return app
    }

    func testFakeAuthBootsIntoSignedInUI() {
        let app = launchApp()
        // The Developer tab bar's Chat tab should appear once signed in.
        XCTAssertTrue(app.tabBars.buttons["Chat"].waitForExistence(timeout: 20))
    }

    func testChatTabShowsComposer() {
        let app = launchApp()
        app.tabBars.buttons["Chat"].tap()
        XCTAssertTrue(app.textFields["chat-composer-input"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["chat-mic-button"].exists)
    }
}
