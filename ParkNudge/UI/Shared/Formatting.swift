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

    static func money(
        minorUnits: Int64,
        currencyCode: String,
        locale: Locale = .current
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currencyCode
        let decimal = NSDecimalNumber(value: minorUnits).multiplying(
            byPowerOf10: Int16(-MoneyParser.fractionDigits(currencyCode: currencyCode, locale: locale))
        )
        return formatter.string(from: decimal) ?? "\(minorUnits) \(currencyCode)"
    }

    static func decimalMoneyText(
        minorUnits: Int64?,
        currencyCode: String,
        locale: Locale = .current
    ) -> String {
        guard let minorUnits else { return "" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.usesGroupingSeparator = false
        let fractionDigits = MoneyParser.fractionDigits(currencyCode: currencyCode, locale: locale)
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        let decimal = NSDecimalNumber(value: minorUnits).multiplying(byPowerOf10: Int16(-fractionDigits))
        return formatter.string(from: decimal) ?? decimal.stringValue
    }
}
