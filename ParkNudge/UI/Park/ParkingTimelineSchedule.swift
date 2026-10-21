import Foundation
import SwiftUI

/// One adaptive schedule drives both the meter hero and the parked-for line.
/// Its iterator recalculates cadence at every entry, so it automatically moves
/// from minute updates to one-second updates at the warning boundary unless a
/// power or motion preference calls for a coarse schedule.
struct ParkingTimelineSchedule: TimelineSchedule {
    let meterExpiry: Date?
    let lowPowerMode: Bool
    let reduceMotion: Bool

    func entries(from startDate: Date, mode _: Mode) -> Entries {
        Entries(
            nextDate: startDate,
            meterExpiry: meterExpiry,
            lowPowerMode: lowPowerMode,
            reduceMotion: reduceMotion
        )
    }

    struct Entries: Sequence, IteratorProtocol {
        var nextDate: Date
        let meterExpiry: Date?
        let lowPowerMode: Bool
        let reduceMotion: Bool

        mutating func next() -> Date? {
            let entry = nextDate
            nextDate = nextDate.addingTimeInterval(
                ParkingTimelinePolicy.cadence(
                    now: entry,
                    meterExpiry: meterExpiry,
                    lowPowerMode: lowPowerMode,
                    reduceMotion: reduceMotion
                )
            )
            return entry
        }

        func makeIterator() -> Entries {
            self
        }
    }
}
