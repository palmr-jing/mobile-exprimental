import XCTest
import SwiftUI
@testable import MobileCommander

final class DesignSystemTests: XCTestCase {

    func testColorHexInitSixDigit() {
        let color = Color(hex: "FF0000")
        XCTAssertNotNil(color)
    }

    func testColorHexInitEightDigit() {
        let color = Color(hex: "80FF0000")
        XCTAssertNotNil(color)
    }

    func testColorHexInitWithHash() {
        let color = Color(hex: "#00FF00")
        XCTAssertNotNil(color)
    }

    func testColorHexInitInvalidLength() {
        let color = Color(hex: "FFF")
        XCTAssertNotNil(color)
    }

    func testSpacingValues() {
        XCTAssertEqual(DS.Spacing.xs, 4)
        XCTAssertEqual(DS.Spacing.sm, 8)
        XCTAssertEqual(DS.Spacing.md, 12)
        XCTAssertEqual(DS.Spacing.lg, 16)
        XCTAssertEqual(DS.Spacing.xl, 20)
        XCTAssertEqual(DS.Spacing.xxl, 24)
    }

    func testSpacingIncreases() {
        XCTAssertLessThan(DS.Spacing.xs, DS.Spacing.sm)
        XCTAssertLessThan(DS.Spacing.sm, DS.Spacing.md)
        XCTAssertLessThan(DS.Spacing.md, DS.Spacing.lg)
        XCTAssertLessThan(DS.Spacing.lg, DS.Spacing.xl)
        XCTAssertLessThan(DS.Spacing.xl, DS.Spacing.xxl)
    }

    func testRadiusValues() {
        XCTAssertEqual(DS.Radius.sm, 8)
        XCTAssertEqual(DS.Radius.md, 12)
        XCTAssertEqual(DS.Radius.lg, 16)
        XCTAssertEqual(DS.Radius.xl, 20)
    }

    func testRadiusIncreases() {
        XCTAssertLessThan(DS.Radius.sm, DS.Radius.md)
        XCTAssertLessThan(DS.Radius.md, DS.Radius.lg)
        XCTAssertLessThan(DS.Radius.lg, DS.Radius.xl)
    }
}
