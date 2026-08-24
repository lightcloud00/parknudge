import Foundation

/// Where a parking meter stands right now.
///
/// The Park screen previously knew only "running" or "expired", and after
/// expiry it rendered a frozen `0:00`. A driver walking back needs the third
/// state — the warning window — and, once the meter is gone, needs to know how
/// long it has been gone rather than being told nothing.
///
/// Derived from absolute dates on every evaluation; nothing here is persisted.
enum MeterState: Equatable {
    /// More than `warningThreshold` left.
    case running(remaining: TimeInterval)
    /// Inside the warning window, but not expired yet.
    case expiringSoon(remaining: TimeInterval)
    /// Past the expiry date, by `since` seconds.
    case expired(since: TimeInterval)

    /// The last quarter hour before expiry, matching the widest free reminder
    /// offset in `ReminderPlanner.freeOffsets` so the tile turns amber at the
    /// same moment the first notification fires.
    static let warningThreshold: TimeInterval = 15 * 60

    static func at(_ now: Date, expiry: Date) -> MeterState {
        let remaining = expiry.timeIntervalSince(now)
        if remaining <= 0 { return .expired(since: -remaining) }
        if remaining <= warningThreshold { return .expiringSoon(remaining: remaining) }
        return .running(remaining: remaining)
    }

    var isExpired: Bool {
        if case .expired = self { return true }
        return false
    }

    /// Fraction of the paid window already spent, clamped to `0...1`.
    ///
    /// A meter saved with an expiry in the past, or extended backwards, would
    /// otherwise produce a negative or runaway bar.
    static func progress(start: Date, expiry: Date, now: Date) -> Double {
        let window = expiry.timeIntervalSince(start)
        guard window > 0 else { return 1 }
        return min(max(now.timeIntervalSince(start) / window, 0), 1)
    }
}

// MARK: - Presentation

extension MeterState {
    /// Headline above the countdown.
    var title: String {
        switch self {
        case .running:
            "Meter time remaining"
        case .expiringSoon:
            "Meter expires soon"
        case .expired(let since):
            "Meter expired \(Self.elapsedPhrase(since)) ago"
        }
    }

    /// The countdown itself. Expired counts *up*, marked with a leading `+`.
    var digits: String {
        switch self {
        case .running(let remaining), .expiringSoon(let remaining):
            ParkNudgeFormatting.duration(remaining)
        case .expired(let since):
            "+" + ParkNudgeFormatting.duration(since)
        }
    }

    /// Spoken form of the tile. VoiceOver reads the whole hero as one element,
    /// so the digits are spelled out rather than read as a bare `1:47:12`.
    func accessibilityDescription(expiry: Date) -> String {
        let clock = expiry.formatted(date: .omitted, time: .shortened)
        switch self {
        case .running(let remaining), .expiringSoon(let remaining):
            return "\(title), \(Self.spokenDuration(remaining)) left, expires at \(clock)"
        case .expired:
            return "\(title), at \(clock)"
        }
    }

    /// Whole-unit phrasing for the title: "12 min", "2 hr", "1 hr 5 min".
    /// Deliberately not `RelativeDateTimeFormatter` — this string is asserted
    /// in tests and must not shift with the formatter's locale heuristics.
    static func elapsedPhrase(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int(interval) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(max(totalMinutes, 1)) min" }
        if minutes == 0 { return "\(hours) hr" }
        return "\(hours) hr \(minutes) min"
    }

    private static func spokenDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int(interval) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 {
            return minutes == 1 ? "1 minute" : "\(minutes) minutes"
        }
        let hourPart = hours == 1 ? "1 hour" : "\(hours) hours"
        if minutes == 0 { return hourPart }
        return "\(hourPart) \(minutes) \(minutes == 1 ? "minute" : "minutes")"
    }
}
