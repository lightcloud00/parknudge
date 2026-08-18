import XCTest
@testable import ParkNudge

final class ReminderPlannerTests: XCTestCase {
    func testShortMeterFiltersPastWarnings() {
        let now = TestFixtures.date
        let expiry = now.addingTimeInterval(8 * 60)

        let plans = ReminderPlanner.plans(
            sessionID: UUID(),
            expiry: expiry,
            offsets: ReminderPlanner.freeOffsets,
            now: now
        )

        XCTAssertEqual(plans.map(\.offsetMinutes), [5, 0])
        XCTAssertTrue(plans.allSatisfy { $0.fireDate > now })
    }

    func testIdentifiersAreDeterministic() {
        let id = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
        XCTAssertEqual(
            ReminderPlanner.identifier(sessionID: id, offsetMinutes: 15),
            "parknudge.meter.ffffffff-ffff-ffff-ffff-ffffffffffff.15"
        )
    }

    func testCustomOffsetsAreUniqueBoundedAndLimited() {
        XCTAssertEqual(
            ReminderPlanner.normalizedOffsets([5, 30, 5, -1, 1_441, 10, 0, 60, 120]),
            [120, 60, 30, 10, 5]
        )
    }
}
