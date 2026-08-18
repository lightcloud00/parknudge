import Foundation

enum ParkNudgeFormatting {
    static func duration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, seconds) }
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func money(minorUnits: Int64, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        let decimal = NSDecimalNumber(value: minorUnits).dividing(by: NSDecimalNumber(value: 100))
        return formatter.string(from: decimal) ?? "\(minorUnits) \(currencyCode)"
    }

    static func decimalMoneyText(minorUnits: Int64?) -> String {
        guard let minorUnits else { return "" }
        return NSDecimalNumber(value: minorUnits)
            .dividing(by: NSDecimalNumber(value: 100))
            .stringValue
    }
}
