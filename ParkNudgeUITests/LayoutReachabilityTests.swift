import XCTest

/// Guards against controls that render but cannot be tapped.
///
/// The Park screen shipped once with `Finish` laid out underneath the iOS 26
/// floating tab bar: it existed, it was visible in a screenshot, and
/// `isHittable` was false until the user happened to scroll a screen that gives
/// no reason to scroll. `exists` and `waitForExistence` pass straight through
/// that, which is why the whole suite stayed green while it was live.
///
/// Run under a non-default appearance or text size with `simctl ui <device>
/// appearance dark` / `content_size accessibility-extra-large` before
/// launching; the assertions are deliberately environment-agnostic.
final class LayoutReachabilityTests: XCTestCase {
    @MainActor
    func testEmptyStateSaveButtonIsReachableAtRest() throws {
        let app = launch()
        assertReachable(app.buttons["save-parking-spot"], "empty-state save button")
    }

    @MainActor
    func testParkScreenControlsAreReachableAtRest() throws {
        let app = launch(seedActiveMeter: true)

        XCTAssertTrue(
            app.otherElements["meter-hero"].waitForExistence(timeout: 5),
            "The seeded session has a meter, so the hero should be on screen"
        )

        // At rest — no scrolling. This is what the user sees on arrival, and
        // where `Finish` was previously unreachable.
        assertReachable(app.buttons["walking-directions"], "Walking Directions")
        assertReachable(app.buttons["finish-parking"], "Finish")
        assertReachable(app.buttons["parking-actions-menu"], "overflow menu")
    }

    @MainActor
    func testPaywallControlsAreReachable() throws {
        let app = launch(seedActiveMeter: true)

        app.buttons["finish-parking"].tap()
        app.buttons["Finish Parking"].tap()

        XCTAssertFalse(
            app.buttons["close-paywall"].waitForExistence(timeout: 1),
            "Completing the free parking loop must not open a paywall"
        )

        app.tabBars.buttons["Settings"].tap()
        assertReachable(app.buttons["settings-lifetime-pro"], "Settings premium intent")
        app.buttons["settings-lifetime-pro"].tap()

        guard app.buttons["close-paywall"].waitForExistence(timeout: 5) else {
            return XCTFail("Choosing the Settings premium intent should raise the paywall")
        }

        // The paywall is an obviously scrollable sheet, so only the escape
        // hatch and the primary action must be reachable without scrolling.
        assertReachable(app.buttons["close-paywall"], "paywall close button")
        assertReachable(app.buttons["purchase-lifetime-pro"], "paywall purchase button")

        // The legal links sit at the bottom by design. That they are reachable
        // *after* scrolling is a different, weaker claim — but still one worth
        // making, since a link nobody can reach is an App Review problem.
        app.swipeUp()
        assertReachable(app.buttons["paywall-privacy"], "paywall privacy link after scrolling")
        assertReachable(app.buttons["paywall-terms"], "paywall terms link after scrolling")

        app.buttons["close-paywall"].tap()

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(
            app.cells.firstMatch.waitForExistence(timeout: 5),
            "History should list the finished session"
        )

        app.tabBars.buttons["Settings"].tap()
        // Not `staticTexts["Version"]`: a `LabeledContent` row is one
        // accessibility element carrying label *and* value, so the bare title
        // never matches. A button is the stable thing to assert on.
        assertReachable(app.buttons["Restore Purchases"], "Settings restore button")
    }

    // MARK: - Helpers

    @MainActor
    private func launch(seedActiveMeter: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + (seedActiveMeter ? ["-ui-test-active-meter"] : [])
        app.launch()
        return app
    }

    @MainActor
    private func assertReachable(
        _ element: XCUIElement,
        _ description: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            element.waitForExistence(timeout: 5),
            "\(description) is missing",
            file: file,
            line: line
        )
        XCTAssertTrue(
            element.isHittable,
            "\(description) exists but is not hittable at rest — frame \(element.frame)",
            file: file,
            line: line
        )
    }
}
