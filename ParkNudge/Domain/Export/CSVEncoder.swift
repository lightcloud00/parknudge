import Foundation

enum ParkingCSVEncoder {
    static let header = [
        "id", "started_at", "ended_at", "duration_seconds", "latitude", "longitude",
        "accuracy_m", "location_label", "floor", "section", "note", "meter_expires_at",
        "paid_amount_minor", "currency_code"
    ]

    static func encode(_ sessions: [ParkingSession]) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let rows = sessions.map { session in
            [
                session.id.uuidString,
                formatter.string(from: session.startedAt),
                session.endedAt.map(formatter.string(from:)) ?? "",
                String(Int(session.duration.rounded())),
                String(format: "%.7f", session.coordinate.latitude),
                String(format: "%.7f", session.coordinate.longitude),
                String(format: "%.1f", session.horizontalAccuracy),
                session.locationLabel ?? "",
                session.floor ?? "",
                session.section ?? "",
                session.note ?? "",
                session.meterExpiresAt.map(formatter.string(from:)) ?? "",
                session.paidAmountMinor.map(String.init) ?? "",
                session.currencyCode ?? ""
            ].map(escape).joined(separator: ",")
        }

        return ([header.joined(separator: ",")] + rows).joined(separator: "\r\n") + "\r\n"
    }

    static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

enum MoneyParser {
    static func minorUnits(from text: String, locale: Locale = .current) -> Int64? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.generatesDecimalNumbers = true
        guard let number = formatter.number(from: text),
              let decimal = number as? NSDecimalNumber,
              decimal.compare(NSDecimalNumber.zero) != .orderedAscending else { return nil }
        let scaled = decimal.multiplying(byPowerOf10: 2)
        return scaled.rounding(accordingToBehavior: NSDecimalNumberHandler(
            roundingMode: .bankers,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )).int64Value
    }
}
