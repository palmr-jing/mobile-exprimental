import XCTest

// Exercises the chat composer: typing, mention autocomplete, and mocked voice
// dictation. Runs against the Firebase emulator with a seeded #general channel.
final class ChatUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launchChat(voice: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["-UITEST", "-FAKE_USER_EMAIL", "test@palmr.ai", "-FAKE_USER_ADMIN", "1"]
        if let voice {
            args += ["-FAKE_VOICE", "-FAKE_VOICE_TRANSCRIPT", voice]
        }
        app.launchArguments = args
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Chat"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Chat"].tap()
        return app
    }

    func testTypeAndSendMessage() {
        let app = launchChat()
        let field = app.textFields["chat-composer-input"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("hello team")
        app.buttons["chat-send"].tap()
        // The message should render in the thread.
        XCTAssertTrue(app.staticTexts["hello team"].waitForExistence(timeout: 10))
    }

    func testVoiceDictationFillsComposer() {
        let app = launchChat(voice: "deploy the latest build")
        XCTAssertTrue(app.buttons["chat-mic-button"].waitForExistence(timeout: 10))
        app.buttons["chat-mic-button"].tap()
        // The mock transcriber injects the canned transcript into the field.
        let field = app.textFields["chat-composer-input"]
        let predicate = NSPredicate(format: "value CONTAINS[c] %@", "deploy the latest build")
        expectation(for: predicate, evaluatedWith: field)
        waitForExpectations(timeout: 10)
    }

    func testMentionAutocompleteAppears() {
        let app = launchChat()
        let field = app.textFields["chat-composer-input"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("@em")
        // Emma is always in the roster, so the dropdown should offer her.
        XCTAssertTrue(app.staticTexts["@emma"].waitForExistence(timeout: 5))
    }

    func testReplyBarAppearsAndCancels() {
        let app = launchChat()
        let field = app.textFields["chat-composer-input"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("reply target")
        app.buttons["chat-send"].tap()

        // Long-press the bubble to open the native context menu, then tap Reply.
        let bubble = app.staticTexts["reply target"]
        XCTAssertTrue(bubble.waitForExistence(timeout: 10))
        bubble.press(forDuration: 1.1)
        let replyItem = app.buttons["Reply"]
        XCTAssertTrue(replyItem.waitForExistence(timeout: 5))
        replyItem.tap()

        // The reply bar (with its cancel control) should now be staged.
        let cancel = app.buttons["chat-cancel-reply"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertFalse(cancel.waitForExistence(timeout: 2))
    }
}
