import XCTest
@testable import MobileCommander

final class AppConfigurationTests: XCTestCase {

    func testIsUITestingIsFalseByDefault() {
        XCTAssertFalse(AppConfiguration.isUITesting)
    }
}
