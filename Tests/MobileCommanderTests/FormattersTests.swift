import XCTest
@testable import MobileCommander

final class FormattersTests: XCTestCase {

    func testDurationUnderOneMinute() {
        XCTAssertEqual(Formatters.duration(ms: 0), "0s")
        XCTAssertEqual(Formatters.duration(ms: 500), "0s")
        XCTAssertEqual(Formatters.duration(ms: 1000), "1s")
        XCTAssertEqual(Formatters.duration(ms: 30000), "30s")
        XCTAssertEqual(Formatters.duration(ms: 59999), "59s")
    }

    func testDurationExactlyOneMinute() {
        XCTAssertEqual(Formatters.duration(ms: 60000), "1m 0s")
    }

    func testDurationOverOneMinute() {
        XCTAssertEqual(Formatters.duration(ms: 90000), "1m 30s")
        XCTAssertEqual(Formatters.duration(ms: 125000), "2m 5s")
    }

    func testDurationLargeValues() {
        XCTAssertEqual(Formatters.duration(ms: 3600000), "60m 0s")
        XCTAssertEqual(Formatters.duration(ms: 5400000), "90m 0s")
    }
}
