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
            encodeRow(session, formatter: formatter)
        }

        return ([header.joined(separator: ",")] + rows).joined(separator: "\r\n") + "\r\n"
    }

    private static func encodeRow(
        _ session: ParkingSession,
        formatter: ISO8601DateFormatter
    ) -> String {
        var columns: [String] = []
        columns.reserveCapacity(header.count)
        columns.append(session.id.uuidString)
        columns.append(formatter.string(from: session.startedAt))
        columns.append(session.endedAt.map { formatter.string(from: $0) } ?? "")
        columns.append(String(Int(session.duration.rounded())))
        columns.append(String(format: "%.7f", session.coordinate.latitude))
        columns.append(String(format: "%.7f", session.coordinate.longitude))
        columns.append(String(format: "%.1f", session.horizontalAccuracy))
        columns.append(session.locationLabel ?? "")
        columns.append(session.floor ?? "")
        columns.append(session.section ?? "")
        columns.append(session.note ?? "")
        columns.append(session.meterExpiresAt.map { formatter.string(from: $0) } ?? "")
        columns.append(session.paidAmountMinor.map { String($0) } ?? "")
        columns.append(session.currencyCode ?? "")
        return columns.map(escape).joined(separator: ",")
    }

    static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

enum MoneyParser {
    static func fractionDigits(currencyCode: String, locale: Locale = .current) -> Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currencyCode
        return max(0, formatter.maximumFractionDigits)
    }

    static func minorUnits(
        from text: String,
        currencyCode: String,
        locale: Locale = .current
    ) -> Int64? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.generatesDecimalNumbers = true
        formatter.isLenient = false
        guard let number = formatter.number(from: text),
              let decimal = number as? NSDecimalNumber,
              decimal.compare(NSDecimalNumber.zero) != .orderedAscending else { return nil }
        let scaled = decimal.multiplying(
            byPowerOf10: Int16(fractionDigits(currencyCode: currencyCode, locale: locale))
        )
        let rounded = scaled.rounding(accordingToBehavior: NSDecimalNumberHandler(
            roundingMode: .bankers,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        ))
        guard rounded != .notANumber,
              rounded.compare(NSDecimalNumber(value: Int64.max)) != .orderedDescending else {
            return nil
        }
        return rounded.int64Value
    }
}
