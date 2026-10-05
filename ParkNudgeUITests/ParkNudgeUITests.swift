import XCTest

final class ParkNudgeUITests: XCTestCase {
    @MainActor
    func testNewCustomerDismissalKeepsParkingLockedAndPurchaseResumesEditor() {
        let app = launch(extraArguments: ["--new-customer-paywall"])
        XCTAssertTrue(app.buttons["save-parking-spot"].waitForExistence(timeout: 5))
        app.buttons["save-parking-spot"].tap()
        XCTAssertTrue(app.buttons["close-paywall"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["confirm-save-parking"].exists)
        app.buttons["close-paywall"].tap()

        XCTAssertTrue(app.buttons["save-parking-spot"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["confirm-save-parking"].exists)
        app.buttons["save-parking-spot"].tap()
        XCTAssertTrue(app.buttons["purchase-lifetime-pro"].waitForExistence(timeout: 5))
        let purchase = app.buttons["purchase-lifetime-pro"]
        for _ in 0..<5 where !purchase.isHittable { app.swipeUp() }
        XCTAssertTrue(purchase.isHittable)
        purchase.tap()

        // The deterministic verified-entitlement fixture exercises sheet
        // dismissal ordering; Apple transaction acceptance is a separate gate.
        XCTAssertTrue(app.buttons["confirm-save-parking"].waitForExistence(timeout: 5))
        app.buttons["confirm-save-parking"].tap()
        XCTAssertTrue(app.buttons["walking-directions"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testNewCustomerCanFinishExistingParkingWithoutPayingAgain() {
        let app = launch(extraArguments: ["--new-customer-paywall", "-ui-test-active-meter"])
        XCTAssertTrue(app.buttons["walking-directions"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["close-paywall"].exists)
        app.buttons["finish-parking"].tap()
        app.buttons["Finish Parking"].tap()
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Union Square Garage"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["close-paywall"].exists)
    }

    @MainActor
    func testSettingsReminderUpsellShowsPaidCoreOnlyForNewCustomers() {
        for newCustomer in [true, false] {
            let app = launch(extraArguments: newCustomer ? ["--new-customer-paywall"] : [])
            app.tabBars.buttons["Settings"].tap()
            app.buttons["Customize with Pro"].tap()
            XCTAssertTrue(app.buttons["close-paywall"].waitForExistence(timeout: 5))
            if newCustomer {
                XCTAssertTrue(app.staticTexts["Unlock parking before saving your first spot"].exists)
                XCTAssertFalse(app.staticTexts["Original"].exists)
            } else {
                XCTAssertTrue(app.staticTexts["Original"].exists)
                XCTAssertFalse(app.staticTexts["Unlock parking before saving your first spot"].exists)
            }
            keepScreenshot(named: newCustomer ? "ParkNudge-new-customer-settings-offer" : "ParkNudge-original-customer-settings-offer")
            app.terminate()
        }
    }

    /// Retains the six raw frames used for the version 1.1 App Store story.
    /// The sequence starts as a new customer, shows the paid-core disclosure,
    /// completes the deterministic purchase, and then shows the unlocked
    /// parking workflow. This keeps the listing aligned with the production
    /// contract while original customers retain their separately tested access.
    @MainActor
    func testAppStorePaidCoreScreenshotStory() throws {
        let fresh = launch(extraArguments: ["--new-customer-paywall"])
        XCTAssertTrue(fresh.buttons["save-parking-spot"].waitForExistence(timeout: 5))
        XCTAssertTrue(fresh.staticTexts["Lifetime Pro is required for new customers. One purchase, no subscription."].exists)
        keepScreenshot(named: "01-ParkNudge-new-customer-home")

        fresh.buttons["save-parking-spot"].tap()
        XCTAssertTrue(fresh.staticTexts["Unlock parking before saving your first spot"].waitForExistence(timeout: 5))
        XCTAssertTrue(fresh.descendants(matching: .any)["paywall-price"].exists)
        keepScreenshot(named: "02-ParkNudge-lifetime-one-time")

        let purchase = fresh.buttons["purchase-lifetime-pro"]
        for _ in 0..<5 where !purchase.isHittable { fresh.swipeUp() }
        XCTAssertTrue(purchase.isHittable)
        purchase.tap()
        XCTAssertTrue(fresh.buttons["confirm-save-parking"].waitForExistence(timeout: 5))
        keepScreenshot(named: "03-ParkNudge-adjust-and-confirm")
        fresh.terminate()

        let active = launch(extraArguments: ["-ui-test-pro", "-ui-test-active-meter"])
        XCTAssertTrue(active.otherElements["meter-hero"].waitForExistence(timeout: 5))
        XCTAssertTrue(active.buttons["walking-directions"].waitForExistence(timeout: 5))
        keepScreenshot(named: "04-ParkNudge-meter-and-directions")

        active.buttons["finish-parking"].tap()
        active.buttons["Finish Parking"].tap()
        active.tabBars.buttons["History"].tap()
        XCTAssertTrue(active.staticTexts["Union Square Garage"].waitForExistence(timeout: 5))
        keepScreenshot(named: "05-ParkNudge-private-history")

        active.tabBars.buttons["Settings"].tap()
        active.swipeUp()
        XCTAssertTrue(active.buttons["Privacy"].waitForExistence(timeout: 5))
        XCTAssertTrue(active.buttons["Terms"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            active.staticTexts[
                "All data stays on this iPhone unless you explicitly share a CSV export."
            ].exists
        )
        keepScreenshot(named: "06-ParkNudge-local-data-and-privacy")
    }

    @MainActor
    func testOriginalCustomerCompletesParkingLoopBeforePremiumExtrasPaywall() throws {
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
