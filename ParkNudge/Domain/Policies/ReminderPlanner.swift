import Foundation

enum ReminderPlanner {
    static let freeOffsets = [15, 5, 0]
    static let maximumCustomOffsets = 5

    static func normalizedOffsets(_ offsets: [Int]) -> [Int] {
        Array(Set(offsets.filter { (0...1_440).contains($0) }))
            .sorted(by: >)
            .prefix(maximumCustomOffsets)
            .map { $0 }
    }

    static func plans(
        sessionID: UUID,
        expiry: Date,
        offsets: [Int],
        now: Date
    ) -> [ReminderPlan] {
        normalizedOffsets(offsets).compactMap { offset in
            let fireDate = expiry.addingTimeInterval(TimeInterval(-offset * 60))
            guard fireDate > now else { return nil }
            return ReminderPlan(
                sessionID: sessionID,
                fireDate: fireDate,
                offsetMinutes: offset,
                notificationIdentifier: identifier(sessionID: sessionID, offsetMinutes: offset)
            )
        }
    }

    static func identifier(sessionID: UUID, offsetMinutes: Int) -> String {
        "parknudge.meter.\(sessionID.uuidString.lowercased()).\(offsetMinutes)"
    }
}
