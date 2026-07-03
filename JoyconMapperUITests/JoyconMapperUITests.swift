import XCTest

@MainActor
final class JoyconMapperUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchAndInputLogSmokePath() throws {
        let app = XCUIApplication()
        // Two CI-runner constraints shape this test:
        // - Forcing AppleLanguages via launch arguments prevents the main
        //   window from presenting, so lookups are locale-independent.
        // - Synthesized clicks never reach the app (the window stays
        //   disabled in the headless session), so the input log sheet is
        //   opened deterministically via a launch argument instead.
        app.launchArguments = ["--ui-testing", "--ui-testing-show-input-log"]
        app.launch()

        if !app.staticTexts["Joy-Con (L) Mapper"].waitForExistence(timeout: 5) {
            print("=== APP HIERARCHY DEBUG ===\n\(app.debugDescription)\n=== END DEBUG ===")
            XCTFail("Header title not found; see hierarchy dump above.")
        }

        XCTAssertTrue(app.buttons["inputLogButton"].waitForExistence(timeout: 5))

        let closeButton = app.buttons["closeInputLogButton"]
        if !closeButton.waitForExistence(timeout: 10) {
            print("=== SHEET DEBUG ===\n\(app.debugDescription)\n=== END SHEET DEBUG ===")
            XCTFail("Input log sheet did not present; see hierarchy dump above.")
        }
        XCTAssertTrue(app.buttons["clearInputLogButton"].exists)
    }
}
