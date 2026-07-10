import XCTest

// Drives the Videos tab from deterministic mock fixtures (-MOCK_VIDEOS), so the
// grid + tap→play routing is verified without Firebase. Catches the "tap one
// reel, a different one opens" class of bug.
final class VideosUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launchMockVideos() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITEST", "-MOCK_VIDEOS"]
        app.launch()
        return app
    }

    func testGridShowsReels() {
        let app = launchMockVideos()
        XCTAssertTrue(app.staticTexts["Muay Thai Kickboxing"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["video-card"].firstMatch.exists)
    }

    func testTappingEachReelOpensThatReel() {
        let app = launchMockVideos()
        // Open several reels — including the first (Muay Thai) and a middle one
        // (BJJ) — and confirm each opens the reel that was tapped, not another.
        for name in ["Muay Thai Kickboxing", "Brazilian Jiu Jitsu", "Open Mat Rolls"] {
            let card = app.staticTexts[name]
            XCTAssertTrue(card.waitForExistence(timeout: 20), "grid missing \(name)")
            card.tap()
            let title = app.staticTexts["reel-title"].firstMatch
            XCTAssertTrue(title.waitForExistence(timeout: 10), "feed didn't open for \(name)")
            XCTAssertEqual(title.label, name, "Tapping \(name) opened a different reel")
            app.buttons["reel-close"].tap()
            XCTAssertTrue(card.waitForExistence(timeout: 10), "didn't return to grid after \(name)")
        }
    }

    // Reproduces the reported bug: open a reel, close it, then open a DIFFERENT
    // reel. The second open must present the reel you tapped — not silently fail.
    func testOpenCloseThenOpenAnother() {
        let app = launchMockVideos()
        func open(_ name: String) {
            let card = app.staticTexts[name]
            XCTAssertTrue(card.waitForExistence(timeout: 20), "grid missing \(name)")
            card.tap()
            let title = app.staticTexts["reel-title"].firstMatch
            XCTAssertTrue(title.waitForExistence(timeout: 10), "feed didn't open for \(name)")
            XCTAssertEqual(title.label, name, "opened a different reel than \(name)")
        }
        func close() {
            app.buttons["reel-close"].tap()
            // The cover must fully tear down — a lingering player/overlay is the
            // signature of an orphaned presentation that would eat grid taps.
            XCTAssertTrue(app.staticTexts["reel-title"].firstMatch.waitForNonExistence(timeout: 10),
                          "feed overlay didn't dismiss")
        }
        // Hammer several open/close cycles alternating reels — the reported bug is
        // that after the first open+close, opening ANY other reel does nothing.
        let sequence = ["Brazilian Jiu Jitsu", "Muay Thai Kickboxing",
                        "Muay Thai Kickboxing", "Brazilian Jiu Jitsu",
                        "Open Mat Rolls", "Muay Thai Kickboxing"]
        for name in sequence { open(name); close() }
    }

    // Geometry invariant (not timing) so it runs identically on iPhone and iPad:
    // every thumbnail must be hittable and no two may overlap. This is the class of
    // bug that made "clicking Muay Thai directly does nothing" on iPad: landscape
    // thumbnails scaled-to-fill inflated each cell's frame to ~600pt so cells
    // overlapped and a tap on one reel landed on the neighbour buried under it.
    // (Reproduced deterministically with the real remote thumbnails: 600pt overlap
    // → 190pt after the clip/width-cap fix in Thumb.)
    func testGridCellsDoNotOverlapAndAreHittable() {
        let app = launchMockVideos()
        XCTAssertTrue(app.staticTexts["Muay Thai Kickboxing"].waitForExistence(timeout: 20))
        let cards = app.buttons.matching(identifier: "video-card").allElementsBoundByIndex
        XCTAssertGreaterThanOrEqual(cards.count, 3, "grid didn't render its cells")
        let frames = cards.map { $0.frame }
        let window = app.windows.firstMatch.frame
        for (i, f) in frames.enumerated() {
            XCTAssertFalse(f.isEmpty, "card \(i) has an empty frame")
            // Only on-screen cards are hittable; ones below the fold (iPhone's
            // narrow 2-col grid) need scrolling, so don't assert hittability there.
            if window.contains(CGPoint(x: f.midX, y: f.midY)) {
                XCTAssertTrue(cards[i].isHittable, "on-screen card \(i) isn't hittable")
            }
        }
        // Non-overlap is the real invariant and holds even for off-screen cards.
        for i in frames.indices {
            for j in frames.indices where j > i {
                let overlap = frames[i].intersection(frames[j])
                XCTAssertTrue(overlap.isNull || overlap.width < 1 || overlap.height < 1,
                              "cards \(i) and \(j) overlap: \(frames[i]) ∩ \(frames[j]) = \(overlap)")
            }
        }
    }

    // The per-tab "Report an issue" button opens a sheet with the description
    // field + a captured screenshot; Report stays disabled until text is entered.
    func testReportIssueSheetOpens() {
        let app = launchMockVideos()
        XCTAssertTrue(app.staticTexts["Muay Thai Kickboxing"].waitForExistence(timeout: 20))
        app.buttons["report-issue"].firstMatch.tap()

        XCTAssertTrue(app.buttons["report-submit"].waitForExistence(timeout: 10), "report sheet didn't open")
        XCTAssertFalse(app.buttons["report-submit"].isEnabled, "Report should be disabled with no description")

        let field = app.textFields["report-description"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "no description field")
        field.tap(); field.typeText("The grid overlaps")
        XCTAssertTrue(app.buttons["report-submit"].isEnabled, "Report should enable once described")

        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Muay Thai Kickboxing"].waitForExistence(timeout: 10))
    }

    // The "Send to chat" affordance opens a share sheet with a destination picker
    // and a Send button — the reel can be posted into chat from the feed.
    func testShareReelToChatOpensSheet() {
        let app = launchMockVideos()
        let card = app.staticTexts["Muay Thai Kickboxing"]
        XCTAssertTrue(card.waitForExistence(timeout: 20))
        card.tap()

        // The paging feed renders several pages' overlays, so match the first.
        let share = app.buttons["reel-share"].firstMatch
        XCTAssertTrue(share.waitForExistence(timeout: 10), "no Send-to-chat button on the feed")
        share.tap()

        XCTAssertTrue(app.staticTexts["Share to chat"].waitForExistence(timeout: 10), "share sheet didn't open")
        XCTAssertTrue(app.buttons["share-send"].exists, "share sheet missing Send")

        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["reel-title"].waitForExistence(timeout: 10), "didn't return to the feed")
    }
}
