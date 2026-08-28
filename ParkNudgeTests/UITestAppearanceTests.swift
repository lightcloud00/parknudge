@testable import ParkNudge
import SwiftUI
import XCTest

final class UITestAppearanceTests: XCTestCase {
    func testLightAndDarkStylesAreAppliedOnlyDuringUITesting() {
        XCTAssertEqual(
            UITestAppearance.colorScheme(arguments: [
                "ParkNudge", "-ui-testing", "-AppleInterfaceStyle", "Light",
            ]),
            .light
        )
        XCTAssertEqual(
            UITestAppearance.colorScheme(arguments: [
                "ParkNudge", "-ui-testing", "-AppleInterfaceStyle", "Dark",
            ]),
            .dark
        )
        XCTAssertNil(
            UITestAppearance.colorScheme(arguments: [
                "ParkNudge", "-AppleInterfaceStyle", "Dark",
            ])
        )
    }

    func testMalformedAndDuplicateStyleArgumentsFailClosed() {
        XCTAssertNil(
            UITestAppearance.colorScheme(arguments: [
                "-ui-testing", "-AppleInterfaceStyle", "Sepia",
            ])
        )
        XCTAssertNil(
            UITestAppearance.colorScheme(arguments: [
                "-ui-testing",
                "-AppleInterfaceStyle", "Light",
                "-AppleInterfaceStyle", "Dark",
            ])
        )
    }
}
