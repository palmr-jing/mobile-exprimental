import XCTest

// Scenario suite — the multi-step, emulator-seeded flows that get recorded on
// video for the Emma dashboard project tab. Distinct from the quick smoke checks
// in SignInUITests: each test here scripts a full user journey end to end.
//
// The headline scenario is reply-to-message with @emma auto-tagging (#811/#835).
// The seeded #general channel (scripts/seed-emulator.mjs) contains one human
// message from Tim and one bot message from Emma, so we can prove the auto-tag
// fires for a reply to Emma but never for a reply to a teammate.
final class ChatScenarioUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private let emmaMessage = "Build 20260625 is green across the fleet"
    private let timMessage = "Welcome to Commander chat!"

    private func launchChat() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITEST", "-FAKE_USER_EMAIL", "test@palmr.ai", "-FAKE_USER_ADMIN", "1"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Chat"].waitForExistence(timeout: 20), "Chat tab never appeared")
        app.tabBars.buttons["Chat"].tap()
        return app
    }

    // Long-press a message bubble and pick "Reply" from the native context menu,
    // mirroring the gesture a user makes on device.
    private func openReply(on bubble: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(bubble.waitForExistence(timeout: 15), "target bubble never loaded")
        bubble.press(forDuration: 1.1)
        let replyItem = app.buttons["Reply"]
        XCTAssertTrue(replyItem.waitForExistence(timeout: 5), "Reply context-menu item missing")
        replyItem.tap()
    }

    private func typeAndSend(_ text: String, in app: XCUIApplication) {
        let field = app.textFields["chat-composer-input"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "composer input missing")
        field.tap()
        field.typeText(text)
        app.buttons["chat-send"].tap()
    }

    // SCENARIO 1: reply to Emma's message → the sent text is auto-tagged with
    // "@emma" so the assistant fires. This is the core of #811/#835.
    func testReplyToEmmaAutoTagsMention() {
        let app = launchChat()

        // Wait for the seeded thread, then reply to Emma's bot message.
        let emmaBubble = app.staticTexts[emmaMessage]
        openReply(on: emmaBubble, in: app)

        // The reply bar should name Emma as the recipient.
        XCTAssertTrue(
            app.staticTexts["Replying to Emma"].waitForExistence(timeout: 5),
            "reply bar did not show 'Replying to Emma'"
        )

        typeAndSend("ship it when ready", in: app)

        // The persisted message must carry the auto-tagged @emma mention.
        let tagged = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '@emma' AND label CONTAINS 'ship it when ready'")
        ).firstMatch
        XCTAssertTrue(tagged.waitForExistence(timeout: 10), "reply to Emma was not auto-tagged with @emma")
    }

    // SCENARIO 2: reply to a teammate (Tim) → NO @emma is injected. Verifies the
    // auto-tag is scoped to bot replies and never spams the assistant.
    func testReplyToTeammateDoesNotTagEmma() {
        let app = launchChat()

        let timBubble = app.staticTexts[timMessage]
        openReply(on: timBubble, in: app)

        XCTAssertTrue(
            app.staticTexts["Replying to Tim"].waitForExistence(timeout: 5),
            "reply bar did not show 'Replying to Tim'"
        )

        typeAndSend("thanks Tim", in: app)

        // The exact, un-prefixed text proves no @emma was prepended (an auto-tag
        // would have produced "@emma thanks Tim", a different label).
        XCTAssertTrue(
            app.staticTexts["thanks Tim"].waitForExistence(timeout: 10),
            "teammate reply text not found unmodified"
        )
        XCTAssertFalse(
            app.staticTexts["@emma thanks Tim"].exists,
            "teammate reply was incorrectly auto-tagged with @emma"
        )
    }

    // SCENARIO 3: the reply bar can be staged and cancelled, leaving the composer
    // clean. Gives the recorded video a clear "compose → cancel" beat.
    func testReplyBarCancels() {
        let app = launchChat()

        openReply(on: app.staticTexts[emmaMessage], in: app)
        let cancel = app.buttons["chat-cancel-reply"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "reply bar cancel control missing")
        cancel.tap()
        XCTAssertFalse(cancel.waitForExistence(timeout: 2), "reply bar did not dismiss on cancel")
    }
}
