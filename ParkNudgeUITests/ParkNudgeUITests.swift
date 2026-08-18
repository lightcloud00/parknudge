import XCTest

final class ParkNudgeUITests: XCTestCase {
    @MainActor
    func testFreshLaunchSaveFinishAndFirstCompletionPaywall() throws {
        let app = launch()
        app.buttons["save-parking-spot"].tap()
        XCTAssertTrue(app.buttons["confirm-save-parking"].waitForExistence(timeout: 3))
        app.buttons["confirm-save-parking"].tap()
        XCTAssertTrue(app.buttons["walking-directions"].waitForExistence(timeout: 3))

        app.buttons["finish-parking"].tap()
        app.buttons["Finish Parking"].tap()
        XCTAssertTrue(app.buttons["close-paywall"].waitForExistence(timeout: 3))
        app.buttons["close-paywall"].tap()
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Parking session"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testDeniedLocationStillOpensManualPinEditor() {
        let app = launch(extraArguments: ["-ui-test-location-denied"])
        app.buttons["save-parking-spot"].tap()
        XCTAssertTrue(app.otherElements["parking-pin-map"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.descendants(matching: .any)["manual-pin-source"].waitForExistence(timeout: 3)
        )
    }

    @MainActor
    func testProLaunchShowsUnlockedSettings() {
        let app = launch(extraArguments: ["-ui-test-pro"])
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Lifetime Pro unlocked"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Add Reminder"].exists)
    }

    @MainActor
    private func launch(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + extraArguments
        app.launch()
        return app
    }
}
