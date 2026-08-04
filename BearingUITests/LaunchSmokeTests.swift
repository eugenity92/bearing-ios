import XCTest

final class LaunchSmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testAppLaunches() {
        let app = XCUIApplication()
        app.launchArguments = ["-useSampleHealthData"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Bearing"].waitForExistence(timeout: 10))
    }
}
