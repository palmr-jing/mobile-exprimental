import XCTest

final class OwnerModeTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--owner-mode"]
        app.launch()
    }

    func testOwnerTabsAreVisible() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        XCTAssertTrue(tabBar.buttons["Home"].exists)
        XCTAssertTrue(tabBar.buttons["Request"].exists)
        XCTAssertTrue(tabBar.buttons["Status"].exists)
    }

    func testHomeIsDefaultTab() {
        let navTitle = app.navigationBars["Home"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5))
    }

    func testHomeShowsAppStatus() {
        XCTAssertTrue(app.staticTexts["Your App Status"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["In Progress"].exists)
        XCTAssertTrue(app.staticTexts["Done Today"].exists)
    }

    func testNavigateToRequestTab() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        tabBar.buttons["Request"].tap()

        let navTitle = app.navigationBars["New Request"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 3))
    }

    func testRequestShowsTemplates() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        tabBar.buttons["Request"].tap()

        XCTAssertTrue(app.staticTexts["What do you need?"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["template-bugFix"].exists)
        XCTAssertTrue(app.buttons["template-newFeature"].exists)
        XCTAssertTrue(app.buttons["template-uiChange"].exists)
        XCTAssertTrue(app.buttons["template-contentUpdate"].exists)
    }

    func testNavigateToStatusTab() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        tabBar.buttons["Status"].tap()

        let navTitle = app.navigationBars["Status"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 3))
    }

    func testStatusShowsOverallProgress() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        tabBar.buttons["Status"].tap()

        XCTAssertTrue(app.staticTexts["Overall Progress"].waitForExistence(timeout: 3))
    }

    func testSelectRequestTemplate() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        tabBar.buttons["Request"].tap()

        let bugFixButton = app.buttons["template-bugFix"]
        XCTAssertTrue(bugFixButton.waitForExistence(timeout: 3))
        bugFixButton.tap()

        XCTAssertTrue(app.staticTexts["Describe what you need"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["submit-request-button"].exists)
    }
}
