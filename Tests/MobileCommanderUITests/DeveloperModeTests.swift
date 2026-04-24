import XCTest

final class DeveloperModeTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--developer-mode"]
        app.launch()
    }

    func testNavigateToTasksTab() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        tabBar.buttons["Tasks"].tap()

        let navTitle = app.navigationBars["Tasks"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 3))
    }

    func testNavigateToNewTaskTab() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        tabBar.buttons["New"].tap()

        let navTitle = app.navigationBars["New Task"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 3))
    }

    func testNavigateToWorkersTab() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        tabBar.buttons["Workers"].tap()

        let navTitle = app.navigationBars["Workers"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 3))
    }

    func testNavigateToSettingsTab() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        tabBar.buttons["Settings"].tap()

        let navTitle = app.navigationBars["Settings"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 3))
    }

    func testNavigateBetweenAllTabs() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        let tabs = ["Dashboard", "Tasks", "New", "Workers", "Settings"]
        for tab in tabs {
            tabBar.buttons[tab].tap()
            XCTAssertTrue(tabBar.buttons[tab].isSelected, "Tab '\(tab)' should be selected")
        }
    }

    func testCreateTaskFormFields() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        tabBar.buttons["New"].tap()

        XCTAssertTrue(app.textFields["project-field"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["path-field"].exists)
        XCTAssertTrue(app.textFields["task-name-field"].exists)
        XCTAssertTrue(app.buttons["create-task-button"].exists)
    }

    func testCreateTaskButtonDisabledWhenEmpty() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        tabBar.buttons["New"].tap()

        let createButton = app.buttons["create-task-button"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 3))
        XCTAssertFalse(createButton.isEnabled)
    }

    func testDashboardShowsMockData() {
        XCTAssertTrue(app.staticTexts["Running"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Pending"].exists)
        XCTAssertTrue(app.staticTexts["Done"].exists)
        XCTAssertTrue(app.staticTexts["Workers"].exists)
    }

    func testTaskListShowsFilterChips() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        tabBar.buttons["Tasks"].tap()

        XCTAssertTrue(app.buttons["All"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Running"].exists)
        XCTAssertTrue(app.buttons["Pending"].exists)
        XCTAssertTrue(app.buttons["Done"].exists)
        XCTAssertTrue(app.buttons["Failed"].exists)
    }

    func testWorkersShowsSummaryCard() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        tabBar.buttons["Workers"].tap()

        XCTAssertTrue(app.staticTexts["Online"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Active"].exists)
        XCTAssertTrue(app.staticTexts["Total Cost"].exists)
    }

    func testSettingsShowsVersionInfo() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        tabBar.buttons["Settings"].tap()

        XCTAssertTrue(app.staticTexts["Version"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["1.0.0"].exists)
    }
}
