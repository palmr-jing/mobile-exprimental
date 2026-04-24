import XCTest
@testable import MobileCommander

final class RequestTemplateTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(RequestTemplate.allCases.count, 4)
    }

    func testDisplayNames() {
        XCTAssertEqual(RequestTemplate.bugFix.displayName, "Fix a Bug")
        XCTAssertEqual(RequestTemplate.newFeature.displayName, "New Feature")
        XCTAssertEqual(RequestTemplate.uiChange.displayName, "UI Change")
        XCTAssertEqual(RequestTemplate.contentUpdate.displayName, "Update Content")
    }

    func testIcons() {
        XCTAssertEqual(RequestTemplate.bugFix.icon, "ladybug")
        XCTAssertEqual(RequestTemplate.newFeature.icon, "sparkles")
        XCTAssertEqual(RequestTemplate.uiChange.icon, "paintbrush")
        XCTAssertEqual(RequestTemplate.contentUpdate.icon, "doc.text")
    }

    func testDefaultProject() {
        for template in RequestTemplate.allCases {
            XCTAssertEqual(template.defaultProject, "palmr-ios")
        }
    }

    func testDefaultPath() {
        for template in RequestTemplate.allCases {
            XCTAssertEqual(template.defaultPath, "~/repos/palmr-ios-2")
        }
    }

    func testPriorities() {
        XCTAssertEqual(RequestTemplate.bugFix.defaultPriority, 3)
        XCTAssertEqual(RequestTemplate.newFeature.defaultPriority, 5)
        XCTAssertEqual(RequestTemplate.uiChange.defaultPriority, 5)
        XCTAssertEqual(RequestTemplate.contentUpdate.defaultPriority, 7)
    }

    func testBugFixHasHigherPriorityThanFeature() {
        XCTAssertLessThan(RequestTemplate.bugFix.defaultPriority, RequestTemplate.newFeature.defaultPriority)
    }

    func testPlaceholdersAreNotEmpty() {
        for template in RequestTemplate.allCases {
            XCTAssertFalse(template.placeholder.isEmpty)
        }
    }

    func testSystemPromptsAreNotEmpty() {
        for template in RequestTemplate.allCases {
            XCTAssertFalse(template.systemPrompt.isEmpty)
        }
    }

    func testIdMatchesRawValue() {
        for template in RequestTemplate.allCases {
            XCTAssertEqual(template.id, template.rawValue)
        }
    }
}
