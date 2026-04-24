import XCTest

final class AppLaunchTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--developer-mode"]
        app.launch()
    }

    func testAppLaunchesSuccessfully() {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    func testDeveloperTabsAreVisible() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        XCTAssertTrue(tabBar.buttons["Dashboard"].exists)
        XCTAssertTrue(tabBar.buttons["Tasks"].exists)
        XCTAssertTrue(tabBar.buttons["New"].exists)
        XCTAssertTrue(tabBar.buttons["Workers"].exists)
        XCTAssertTrue(tabBar.buttons["Settings"].exists)
    }

    func testDashboardIsDefaultTab() {
        let navTitle = app.navigationBars["Commander"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5))
    }
}
