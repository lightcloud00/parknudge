import UIKit
import XCTest

final class MeterContrastTests: XCTestCase {
    func testWarningAndExpiredInkClearBodyTextContrastInBothAppearances() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            let warning = try contrast(
                foreground: color(named: "MeterWarnInk", traits: traits),
                background: color(named: "MeterWarnSurface", traits: traits)
            )
            let expired = try contrast(
                foreground: color(named: "MeterAlertInk", traits: traits),
                background: color(named: "MeterAlertSurface", traits: traits)
            )
            XCTAssertGreaterThanOrEqual(warning, 4.5, "warning contrast failed in \(style)")
            XCTAssertGreaterThanOrEqual(expired, 4.5, "expired contrast failed in \(style)")
        }
    }

    private func color(named name: String, traits: UITraitCollection) throws -> UIColor {
        try XCTUnwrap(UIColor(named: name, in: .main, compatibleWith: traits))
    }

    private func contrast(foreground: UIColor, background: UIColor) throws -> Double {
        let foregroundLuminance = try luminance(foreground)
        let backgroundLuminance = try luminance(background)
        let lighter = max(foregroundLuminance, backgroundLuminance)
        let darker = min(foregroundLuminance, backgroundLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func luminance(_ color: UIColor) throws -> Double {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            throw ColorError.unreadable
        }

        func linear(_ channel: CGFloat) -> Double {
            let value = Double(channel)
            return value <= 0.04045
                ? value / 12.92
                : pow((value + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    private enum ColorError: Error {
        case unreadable
    }
}
