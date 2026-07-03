import XCTest

@MainActor
final class JoyconMapperUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchAndInputLogSmokePath() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launchEnvironment = [
            "AppleLanguages": "(en)",
            "AppleLocale": "en_US"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Joy-Con (L) Mapper"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["inputLogButton"].waitForExistence(timeout: 5))

        app.buttons["inputLogButton"].click()

        XCTAssertTrue(app.staticTexts["Input Log"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["clearInputLogButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["closeInputLogButton"].waitForExistence(timeout: 5))
    }
}
