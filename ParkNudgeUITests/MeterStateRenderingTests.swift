import XCTest

final class MeterStateRenderingTests: XCTestCase {
    private enum Appearance: String, CaseIterable {
        case light = "Light"
        case dark = "Dark"
    }

    private struct Scenario {
        let name: String
        let offset: TimeInterval
        let labelPrefix: String
        let valuePrefix: String?
    }

    /// Proves that running, warning, and expired meters all render in both
    /// supported appearances. Each attachment is retained even on success so
    /// the fleet receipt carries visual evidence rather than assertions alone.
    @MainActor
    func testEveryMeterStateRendersInLightAndDark() {
        let scenarios = [
            Scenario(
                name: "running",
                offset: 3600,
                labelPrefix: "Meter time remaining",
                valuePrefix: nil
            ),
            Scenario(
                name: "expiring",
                offset: 600,
                labelPrefix: "Meter expires soon",
                valuePrefix: nil
            ),
            Scenario(
                name: "expired",
                offset: -720,
                labelPrefix: "Meter expired",
                valuePrefix: "+"
            ),
        ]

        for appearance in Appearance.allCases {
            for scenario in scenarios {
                let app = launch(offset: scenario.offset, appearance: appearance)
                defer { app.terminate() }

                let hero = app.otherElements["meter-hero"]
                XCTAssertTrue(
                    hero.waitForExistence(timeout: 5),
                    "Missing \(scenario.name) meter in \(appearance.rawValue) appearance"
                )
                XCTAssertTrue(
                    hero.label.hasPrefix(scenario.labelPrefix),
                    "Unexpected \(scenario.name) label in \(appearance.rawValue): \(hero.label)"
                )
                if let valuePrefix = scenario.valuePrefix {
                    XCTAssertTrue(
                        meterValue(hero).hasPrefix(valuePrefix),
                        "Unexpected \(scenario.name) value in \(appearance.rawValue): \(meterValue(hero))"
                    )
                }

                attachScreenshot(
                    app,
                    name: "meter-\(scenario.name)-\(appearance.rawValue.lowercased())"
                )
            }
        }
    }

    @MainActor
    func testExpiredMeterCountsUpFromAbsoluteTime() {
        let app = launch(offset: -10, appearance: .light)
        defer { app.terminate() }

        let hero = app.otherElements["meter-hero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        let initialValue = meterValue(hero)

        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != %@", initialValue),
            object: hero
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [changed], timeout: 3),
            .completed,
            "Expired meter stayed frozen at \(initialValue)"
        )
        XCTAssertTrue(meterValue(hero).hasPrefix("+"))
        attachScreenshot(app, name: "meter-expired-count-up")
    }

    @MainActor
    func testLowPowerModeUsesTruthfulWholeMinuteDigits() {
        let app = launch(
            offset: 600,
            appearance: .light,
            extraArguments: ["-ui-test-low-power-mode"]
        )
        defer { app.terminate() }

        let hero = app.otherElements["meter-hero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        let value = meterValue(hero)
        XCTAssertFalse(value.contains(":"), "Low Power value exposes stale seconds: \(value)")
        XCTAssertTrue(value.hasSuffix("m"), "Expected whole-minute Low Power value: \(value)")
        attachScreenshot(app, name: "meter-low-power-coarse")
    }

    @MainActor
    private func launch(
        offset: TimeInterval,
        appearance: Appearance,
        extraArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-ui-test-meter-offset=\(offset)",
            "-AppleInterfaceStyle",
            appearance.rawValue,
        ] + extraArguments
        app.launch()
        return app
    }

    private func meterValue(_ hero: XCUIElement) -> String {
        hero.value as? String ?? ""
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
