import XCTest

/// The first-launch introduction. `-ui-test-onboarding` makes a UI-test
/// launch behave like a first launch; every other UI test starts past it.
final class OnboardingUITests: XCTestCase {
    @MainActor
    func testIntroductionCompletesWithARealFirstSaveAndReminders() {
        let app = launch(["-ui-test-onboarding", "-ui-test-notifications-undetermined"])

        XCTAssertTrue(app.otherElements["onboarding-step-promise"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["close-paywall"].exists, "No forced first-launch paywall")
        keepScreenshot(named: "ParkNudge-onboarding-1-promise")
        app.buttons["onboarding-continue"].tap()

        XCTAssertTrue(app.otherElements["onboarding-step-parkingStyle"].waitForExistence(timeout: 5))
        app.buttons["onboarding-style-streetMeter"].tap()
        XCTAssertTrue(app.buttons["onboarding-style-streetMeter"].isSelected)
        app.buttons["onboarding-continue"].tap()

        XCTAssertTrue(app.otherElements["onboarding-step-location"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding-skip"].exists, "A permission explanation offers only Continue")
        keepScreenshot(named: "ParkNudge-onboarding-3-location")
        app.buttons["onboarding-continue"].tap()

        XCTAssertTrue(app.otherElements["onboarding-step-firstSave"].waitForExistence(timeout: 5))
        app.buttons["1 hr"].tap()
        keepScreenshot(named: "ParkNudge-onboarding-4-first-save")
        app.buttons["onboarding-save-first-spot"].tap()

        XCTAssertTrue(app.otherElements["onboarding-step-reminders"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding-skip"].exists)
        app.buttons["onboarding-enable-reminders"].tap()

        XCTAssertTrue(app.otherElements["onboarding-step-pro"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["close-paywall"].exists, "The teaser is not the paywall")
        keepScreenshot(named: "ParkNudge-onboarding-6-pro-teaser")
        app.buttons["onboarding-see-pro"].tap()
        XCTAssertTrue(app.buttons["close-paywall"].waitForExistence(timeout: 5))
        app.buttons["close-paywall"].tap()
        XCTAssertTrue(app.buttons["onboarding-finish"].waitForExistence(timeout: 5))
        app.buttons["onboarding-finish"].tap()

        // The first save was real: the Park tab shows it with its meter.
        XCTAssertTrue(app.buttons["walking-directions"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["meter-hero"].exists)
        XCTAssertFalse(app.otherElements["onboarding-step-promise"].exists)
    }

    @MainActor
    func testSkipGoesStraightToTheParkTabWithoutAnOffer() {
        let app = launch(["-ui-test-onboarding"])
        XCTAssertTrue(app.buttons["onboarding-skip"].waitForExistence(timeout: 5))
        app.buttons["onboarding-skip"].tap()

        XCTAssertTrue(app.buttons["save-parking-spot"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["onboarding-step-promise"].exists)
        XCTAssertFalse(app.buttons["close-paywall"].exists)
    }

    @MainActor
    func testSkipFromTheFirstSaveScreenSavesNothing() {
        let app = launch(["-ui-test-onboarding"])
        XCTAssertTrue(app.buttons["onboarding-continue"].waitForExistence(timeout: 5))
        app.buttons["onboarding-continue"].tap()
        XCTAssertTrue(app.otherElements["onboarding-step-parkingStyle"].waitForExistence(timeout: 5))
        app.buttons["onboarding-continue"].tap()
        XCTAssertTrue(app.otherElements["onboarding-step-location"].waitForExistence(timeout: 5))
        app.buttons["onboarding-continue"].tap()

        XCTAssertTrue(app.buttons["onboarding-skip"].waitForExistence(timeout: 5))
        app.buttons["onboarding-skip"].tap()
        XCTAssertTrue(app.buttons["save-parking-spot"].waitForExistence(timeout: 5), "No spot was saved")
    }

    @MainActor
    func testDriverWithASavedSpotStartsInTheApp() {
        let app = launch(["-ui-test-onboarding", "-ui-test-active-meter"])
        XCTAssertTrue(app.buttons["walking-directions"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["onboarding-step-promise"].exists)
    }

    /// Replaying with a spot already saved passes over the first-save screens,
    /// so it can never create a second session.
    @MainActor
    func testSettingsReplayShowsTheIntroductionAgain() {
        let app = launch(["-ui-test-active-meter"])
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Settings"].tap()

        let replay = app.buttons["settings-replay-onboarding"]
        for _ in 0..<5 where !(replay.exists && replay.isHittable) {
            app.swipeUp()
        }
        replay.tap()

        XCTAssertTrue(app.otherElements["onboarding-step-promise"].waitForExistence(timeout: 5))
        app.buttons["onboarding-continue"].tap()
        XCTAssertTrue(app.otherElements["onboarding-step-parkingStyle"].waitForExistence(timeout: 5))
        app.buttons["onboarding-continue"].tap()
        XCTAssertTrue(app.otherElements["onboarding-step-pro"].waitForExistence(timeout: 5))
        app.buttons["onboarding-close"].tap()

        XCTAssertTrue(app.tabBars.buttons["Park"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Park"].tap()
        XCTAssertTrue(app.buttons["walking-directions"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func launch(_ extraArguments: [String]) -> XCUIApplication {
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
