import XCTest

@MainActor
final class JoyconMapperUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // The headless CI runner cannot activate the app: synthesized clicks
    // never land and SwiftUI sheet presentation is suppressed, so this
    // smoke test is limited to launch + main window rendering. Sheet
    // interactions are covered by the manual hardware checklist. Forcing
    // AppleLanguages via launch arguments prevents the window from
    // presenting at all, so lookups stay locale-independent instead.
    func testLaunchShowsMainWindowUI() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        if !app.staticTexts["Joy-Con (L) Mapper"].waitForExistence(timeout: 5) {
            print("=== APP HIERARCHY DEBUG ===\n\(app.debugDescription)\n=== END DEBUG ===")
            XCTFail("Header title not found; see hierarchy dump above.")
        }

        XCTAssertTrue(app.buttons["inputLogButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.windows.firstMatch.exists)
    }
}
