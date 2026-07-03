import XCTest

@MainActor
final class JoyconMapperUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchAndInputLogSmokePath() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        if !app.staticTexts["Joy-Con (L) Mapper"].waitForExistence(timeout: 5) {
            print("=== APP HIERARCHY DEBUG ===\n\(app.debugDescription)\n=== END DEBUG ===")
            XCTFail("Header title not found; see hierarchy dump above.")
        }

        let inputLogButton = app.buttons["inputLogButton"]
        XCTAssertTrue(inputLogButton.waitForExistence(timeout: 5))

        // The sheet can miss the first click while the window is still settling
        // on slow CI runners, so retry until its close button appears.
        app.activate()
        let closeButton = app.buttons["closeInputLogButton"]
        var attempts = 0
        repeat {
            inputLogButton.click()
            attempts += 1
        } while !closeButton.waitForExistence(timeout: 4) && attempts < 4

        XCTAssertTrue(closeButton.exists)
        XCTAssertTrue(app.buttons["clearInputLogButton"].exists)
    }
}
