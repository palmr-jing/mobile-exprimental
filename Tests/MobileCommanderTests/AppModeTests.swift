import XCTest
@testable import MobileCommander

final class AppModeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(AppMode.allCases.count, 2)
    }

    func testRawValues() {
        XCTAssertEqual(AppMode.developer.rawValue, "developer")
        XCTAssertEqual(AppMode.owner.rawValue, "owner")
    }

    func testDisplayNames() {
        XCTAssertEqual(AppMode.developer.displayName, "Developer")
        XCTAssertEqual(AppMode.owner.displayName, "Owner")
    }

    func testDescriptions() {
        XCTAssertTrue(AppMode.developer.description.contains("Full control"))
        XCTAssertTrue(AppMode.owner.description.contains("Simple"))
    }

    func testIcons() {
        XCTAssertEqual(AppMode.developer.icon, "terminal")
        XCTAssertEqual(AppMode.owner.icon, "storefront")
    }

    func testInitFromRawValue() {
        XCTAssertEqual(AppMode(rawValue: "developer"), .developer)
        XCTAssertEqual(AppMode(rawValue: "owner"), .owner)
        XCTAssertNil(AppMode(rawValue: "admin"))
    }
}
