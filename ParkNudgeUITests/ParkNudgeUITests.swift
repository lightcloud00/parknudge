import XCTest

final class ParkNudgeUITests: XCTestCase {
    @MainActor
    func testFreshLaunchCompletesFreeLoopBeforePremiumIntentPaywall() throws {
        let app = launch()
        app.buttons["save-parking-spot"].tap()
        XCTAssertTrue(app.buttons["confirm-save-parking"].waitForExistence(timeout: 3))
        app.buttons["confirm-save-parking"].tap()
        XCTAssertTrue(app.buttons["walking-directions"].waitForExistence(timeout: 3))

        app.buttons["finish-parking"].tap()
        app.buttons["Finish Parking"].tap()
        XCTAssertFalse(
            app.buttons["close-paywall"].waitForExistence(timeout: 1),
            "The first completed parking session is free and must not open a paywall"
        )
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Parking session"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["settings-lifetime-pro"].waitForExistence(timeout: 3))
        app.buttons["settings-lifetime-pro"].tap()
        XCTAssertTrue(app.buttons["close-paywall"].waitForExistence(timeout: 3))
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

    /// Keeps a real StoreKit-backed capture of the exact paywall shown to App Review.
    /// This deliberately omits `-ui-testing`, so the app reads the localized price
    /// from the scheme's StoreKit configuration instead of the UI-test purchase stub.
    @MainActor
    func testAppReviewLifetimePaywallScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["settings-lifetime-pro"].waitForExistence(timeout: 8))
        app.buttons["settings-lifetime-pro"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["paywall-price"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["purchase-lifetime-pro"].waitForExistence(timeout: 5))
        keepScreenshot(named: "ParkNudge-IAP-review-paywall-top")

        app.swipeUp()
        XCTAssertTrue(app.buttons["purchase-lifetime-pro"].isHittable)
        keepScreenshot(named: "ParkNudge-IAP-review-paywall-purchase")
    }

    @MainActor
    private func launch(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + extraArguments
        app.launch()
        return app
    }

    private func keepScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
