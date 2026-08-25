import Foundation

/// Chooses how often the Park screen needs a new wall-clock sample.
///
/// The countdown is always recomputed from absolute dates. A coarser cadence
/// can skip unnecessary redraws, but it can never accumulate timer drift.
enum ParkingTimelinePolicy {
    static let fineCadence: TimeInterval = 1
    static let coarseCadence: TimeInterval = 60
    static let progressAnimationDuration: TimeInterval = 0.25

    static func cadence(
        now: Date,
        meterExpiry: Date?,
        lowPowerMode: Bool
    ) -> TimeInterval {
        if lowPowerMode { return coarseCadence }
        guard let meterExpiry else { return coarseCadence }
        let distanceFromExpiry = abs(meterExpiry.timeIntervalSince(now))
        return distanceFromExpiry <= MeterState.warningThreshold ? fineCadence : coarseCadence
    }

    /// The parked-for line is supporting context, not a stopwatch. Whole
    /// minutes keep it truthful at the coarse cadence without displaying stale
    /// seconds while a long-running meter is on screen.
    static func elapsedDescription(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int(interval) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(max(totalMinutes, 1)) min" }
        if minutes == 0 { return "\(hours) hr" }
        return "\(hours) hr \(minutes) min"
    }

    static func progressAnimation(reduceMotion: Bool) -> TimeInterval? {
        reduceMotion ? nil : progressAnimationDuration
    }
}
