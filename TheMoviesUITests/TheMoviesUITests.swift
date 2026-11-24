import XCTest

/// End-to-end flows against deterministic stub data (no network, no API key).
final class TheMoviesUITests: XCTestCase {
    private static let timeout: TimeInterval = 8
    private static let maxSwipes = 12

    // Stub catalogue ids: genre 28 (Action) × 10_000 + index.
    private let movieWithEverything = "movie-card-280001"
    private let movieWithoutTrailerOrReviews = "movie-card-280000"
    private let movieOnSecondPage = "movie-card-280025"

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Positive flows

    @MainActor
    func testBrowseGenreMoviesDetailAndReviews() {
        let app = launch(scenario: "standard")

        tapElement("genre-card-28", in: app)
        attachScreenshot("02-movies-dark", app)

        tapElement(movieWithEverything, in: app)
        XCTAssertTrue(element("detail-title", in: app).waitForExistence(timeout: Self.timeout))
        XCTAssertTrue(element("play-trailer-button", in: app).waitForExistence(timeout: Self.timeout))
        attachScreenshot("03-detail-dark", app)

        let seeAll = element("see-all-reviews", in: app)
        swipeUntilHittable(seeAll, in: app)
        attachScreenshot("04-detail-lower-dark", app)
        seeAll.tap()

        XCTAssertTrue(element("review-card-0", in: app).waitForExistence(timeout: Self.timeout))
        attachScreenshot("05-reviews-dark", app)
    }

    @MainActor
    func testEndlessScrollingLoadsTheNextPage() {
        let app = launch(scenario: "standard")
        tapElement("genre-card-28", in: app)
        XCTAssertTrue(element(movieWithEverything, in: app).waitForExistence(timeout: Self.timeout))

        swipeUntilExists(movieOnSecondPage, in: app)
        XCTAssertTrue(element(movieOnSecondPage, in: app).exists)
    }

    @MainActor
    func testTrailerSheetOpensAndCloses() {
        let app = launch(scenario: "standard")
        tapElement("genre-card-28", in: app)
        tapElement(movieWithEverything, in: app)

        tapElement("play-trailer-button", in: app)
        XCTAssertTrue(element("trailer-sheet", in: app).waitForExistence(timeout: Self.timeout))
        attachScreenshot("06-trailer-dark", app)

        tapElement("close-trailer", in: app)
        XCTAssertTrue(element("trailer-sheet", in: app).waitForNonExistence(timeout: Self.timeout))
    }

    @MainActor
    func testSettingsShowsAppearanceOptions() {
        let app = launch(scenario: "standard")
        tapElement("settings-button", in: app)
        XCTAssertTrue(element("appearance-light", in: app).waitForExistence(timeout: Self.timeout))
        XCTAssertTrue(element("appearance-dark", in: app).exists)
        attachScreenshot("07-settings-dark", app)
        tapElement("settings-done", in: app)
        XCTAssertTrue(element("appearance-light", in: app).waitForNonExistence(timeout: Self.timeout))
    }

    @MainActor
    func testLightModeRendersMainScreens() {
        let app = launch(scenario: "standard", appearance: "light")
        XCTAssertTrue(element("genre-card-28", in: app).waitForExistence(timeout: Self.timeout))
        attachScreenshot("01-genres-light", app)

        tapElement("genre-card-28", in: app)
        XCTAssertTrue(element(movieWithEverything, in: app).waitForExistence(timeout: Self.timeout))
        attachScreenshot("02-movies-light", app)

        tapElement(movieWithEverything, in: app)
        XCTAssertTrue(element("play-trailer-button", in: app).waitForExistence(timeout: Self.timeout))
        attachScreenshot("03-detail-light", app)
    }

    @MainActor
    func testLandscapePosterFlowBrowsesAndOpensDetail() {
        let app = launch(scenario: "standard")
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }

        tapElement("genre-card-28", in: app)
        let flow = element("poster-flow", in: app)
        XCTAssertTrue(flow.waitForExistence(timeout: Self.timeout))
        XCTAssertTrue(element("flow-details", in: app).waitForExistence(timeout: Self.timeout))
        attachScreenshot("14-landscape-flow-dark", app)

        flow.swipeLeft()
        attachScreenshot("15-landscape-flow-swiped-dark", app)

        tapElement("flow-details", in: app)
        XCTAssertTrue(element("detail-title", in: app).waitForExistence(timeout: Self.timeout))
        attachScreenshot("16-landscape-detail-dark", app)
    }

    @MainActor
    func testLandscapeFlowStaysCenteredAfterRotation() {
        let app = launch(scenario: "standard")
        tapElement("genre-card-28", in: app)
        XCTAssertTrue(element(movieWithEverything, in: app).waitForExistence(timeout: Self.timeout))

        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(element("poster-flow", in: app).waitForExistence(timeout: Self.timeout))
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(element(movieWithEverything, in: app).waitForExistence(timeout: Self.timeout))
        XCUIDevice.shared.orientation = .landscapeLeft

        let focused = element("flow-poster-280000", in: app)
        XCTAssertTrue(focused.waitForExistence(timeout: Self.timeout))
        // Allow the deal-in and re-centring animations to settle.
        _ = element("flow-details", in: app).waitForExistence(timeout: Self.timeout)
        Thread.sleep(forTimeInterval: 1.5)

        let window = app.windows.firstMatch.frame
        let offset = abs(focused.frame.midX - window.midX)
        XCTAssertLessThan(offset, window.width * 0.15, "Focused poster is off-centre by \(offset)pt")
        attachScreenshot("19-landscape-after-rotation-dark", app)
    }

    @MainActor
    func testLongReviewExpandsAndStaysSharp() {
        let app = launch(scenario: "standard")
        tapElement("genre-card-28", in: app)
        tapElement(movieWithEverything, in: app)
        tapElement("see-all-reviews", in: app)

        // Review 0 in the stub catalogue is four paragraphs long.
        let review = element("review-card-0", in: app)
        XCTAssertTrue(review.waitForExistence(timeout: Self.timeout))
        review.tap()
        attachScreenshot("17-long-review-expanded-dark", app)
        app.swipeUp(velocity: .slow)
        attachScreenshot("18-long-review-scrolled-dark", app)
    }

    @MainActor
    func testSearchByMovieNameOpensDetail() {
        let app = launch(scenario: "standard")
        XCTAssertTrue(element("genre-card-28", in: app).waitForExistence(timeout: Self.timeout))
        search("midnight", in: app)

        let firstResult = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'search-result-'")).firstMatch
        XCTAssertTrue(firstResult.waitForExistence(timeout: Self.timeout))
        attachScreenshot("12-search-dark", app)

        firstResult.tap()
        XCTAssertTrue(element("detail-title", in: app).waitForExistence(timeout: Self.timeout))
    }

    // MARK: - Negative flows

    @MainActor
    func testSearchWithNoMatchesShowsEmptyState() {
        let app = launch(scenario: "standard")
        XCTAssertTrue(element("genre-card-28", in: app).waitForExistence(timeout: Self.timeout))
        search("qqqzzz", in: app)
        XCTAssertTrue(element("empty-state", in: app).waitForExistence(timeout: Self.timeout))
        attachScreenshot("13-search-empty-dark", app)
    }

    @MainActor
    func testMovieWithoutTrailerOrReviewsShowsFallbacks() {
        let app = launch(scenario: "standard")
        tapElement("genre-card-28", in: app)
        tapElement(movieWithoutTrailerOrReviews, in: app)

        XCTAssertTrue(element("no-trailer", in: app).waitForExistence(timeout: Self.timeout))
        XCTAssertTrue(element("no-reviews", in: app).waitForExistence(timeout: Self.timeout))
        XCTAssertFalse(element("see-all-reviews", in: app).exists)
    }

    @MainActor
    func testOfflineShowsErrorWithRetry() {
        let app = launch(scenario: "failure")
        XCTAssertTrue(element("error-state", in: app).waitForExistence(timeout: Self.timeout))
        attachScreenshot("08-error-dark", app)

        tapElement("retry-button", in: app)
        XCTAssertTrue(element("error-state", in: app).waitForExistence(timeout: Self.timeout))
    }

    @MainActor
    func testEmptyCatalogueShowsEmptyState() {
        let app = launch(scenario: "empty")
        XCTAssertTrue(element("empty-state", in: app).waitForExistence(timeout: Self.timeout))
        attachScreenshot("09-empty-dark", app)
    }

    @MainActor
    func testLoadMoreFailureShowsInlineRetryThatRecovers() {
        let app = launch(scenario: "flakyPagination")
        tapElement("genre-card-28", in: app)
        XCTAssertTrue(element(movieWithEverything, in: app).waitForExistence(timeout: Self.timeout))

        let loadMoreError = element("load-more-error", in: app)
        swipeUntilExists("load-more-error", in: app)
        attachScreenshot("10-load-more-error-dark", app)

        let retry = element("inline-retry-button", in: app)
        swipeUntilHittable(retry, in: app)
        retry.tap()
        XCTAssertTrue(loadMoreError.waitForNonExistence(timeout: Self.timeout))
        swipeUntilExists(movieOnSecondPage, in: app)
    }

    @MainActor
    func testMalformedAPIKeyIsRejectedAndDemoModeWorks() {
        let app = launch(scenario: "onboarding")
        let field = element("api-key-field", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: Self.timeout))
        field.tap()
        field.typeText("not-a-real-key")
        tapElement("connect-button", in: app)

        XCTAssertTrue(element("api-key-error", in: app).waitForExistence(timeout: Self.timeout))
        attachScreenshot("11-invalid-key-dark", app)

        tapElement("demo-button", in: app)
        XCTAssertTrue(element("genre-card-28", in: app).waitForExistence(timeout: Self.timeout))
    }

    // MARK: - Helpers

    @MainActor
    private func launch(scenario: String, appearance: String = "dark") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-appearance.preference", appearance]
        app.launchEnvironment = ["STUB_SCENARIO": scenario]
        app.launch()
        return app
    }

    @MainActor
    private func search(_ text: String, in app: XCUIApplication) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: Self.timeout))
        field.tap()
        field.typeText(text)
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    @MainActor
    private func tapElement(_ identifier: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(identifier, in: app)
        XCTAssertTrue(target.waitForExistence(timeout: Self.timeout), "Missing \(identifier)", file: file, line: line)
        swipeUntilHittable(target, in: app)
        target.tap()
    }

    @MainActor
    private func swipeUntilHittable(_ target: XCUIElement, in app: XCUIApplication) {
        var swipes = 0
        while !target.isHittable, swipes < Self.maxSwipes {
            app.swipeUp(velocity: .slow)
            swipes += 1
        }
    }

    @MainActor
    private func swipeUntilExists(_ identifier: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(identifier, in: app)
        var swipes = 0
        while !target.waitForExistence(timeout: 1), swipes < Self.maxSwipes {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(target.exists, "Never found \(identifier)", file: file, line: line)
    }

    @MainActor
    private func attachScreenshot(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
