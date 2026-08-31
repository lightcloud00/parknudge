import XCTest

final class ParkNudgeStoreScreenshotTests: XCTestCase {
    /// Retains the five truthful iPhone frames used by the App Store media lane.
    ///
    /// Every launch uses the in-memory UI-test environment. The seeded active
    /// parking session is sample data, never a claim that ParkNudge detected a
    /// real car or location automatically.
    @MainActor
    func testCaptureStoreScreenshots() {
        let emptyApp = launch()
        defer { emptyApp.terminate() }

        XCTAssertTrue(
            emptyApp.buttons["save-parking-spot"].waitForExistence(timeout: 5),
            "The free empty-state save action should be visible"
        )
        keepScreenshot(named: "01-save-where-you-parked")
        emptyApp.terminate()

        let activeApp = launch(extraArguments: ["-ui-test-active-meter"])
        defer { activeApp.terminate() }

        XCTAssertTrue(activeApp.otherElements["meter-hero"].waitForExistence(timeout: 5))
        XCTAssertTrue(activeApp.buttons["walking-directions"].waitForExistence(timeout: 5))
        keepScreenshot(named: "04-navigate-back-to-your-car")

        let editButton = activeApp.buttons["Edit or Extend"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()
        XCTAssertTrue(activeApp.buttons["confirm-save-parking"].waitForExistence(timeout: 5))

        let meterToggle = activeApp.descendants(matching: .any)["meter-toggle"]
        scrollUntilHittable(meterToggle, in: activeApp)
        let reminderPreview = activeApp.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "You'll be nudged at")
        ).firstMatch
        XCTAssertTrue(reminderPreview.waitForExistence(timeout: 3))
        keepScreenshot(named: "03-set-a-return-reminder")

        let photoButton = activeApp.buttons["Choose Photo"]
        scrollUntilHittable(photoButton, in: activeApp)
        let costButton = activeApp.buttons["Add a parking cost with Pro"]
        scrollUntilHittable(costButton, in: activeApp)
        XCTAssertTrue(photoButton.exists)
        keepScreenshot(named: "02-add-a-photo-note-or-cost")

        let cancelButton = activeApp.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3))
        cancelButton.tap()
        XCTAssertTrue(activeApp.buttons["walking-directions"].waitForExistence(timeout: 5))

        activeApp.tabBars.buttons["Settings"].tap()
        let localDataCopy = activeApp.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "All data stays on this iPhone")
        ).firstMatch
        scrollUntilHittable(localDataCopy, in: activeApp)
        XCTAssertTrue(activeApp.buttons["Delete All Parking Data"].exists)
        keepScreenshot(named: "05-keep-location-data-private")
    }

    @MainActor
    private func launch(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-AppleInterfaceStyle", "Light",
        ] + extraArguments
        app.launch()
        return app
    }

    @MainActor
    private func scrollUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for _ in 0..<6 where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(
            element.exists && element.isHittable,
            "Expected element to become visible after bounded scrolling: \(element)",
            file: file,
            line: line
        )
    }

    private func keepScreenshot(named name: String) {
        Thread.sleep(forTimeInterval: 0.4)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
