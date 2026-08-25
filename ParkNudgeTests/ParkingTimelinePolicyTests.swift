import Foundation
@testable import ParkNudge
import XCTest

final class ParkingTimelinePolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testLongMeterUsesOneMinuteCadence() {
        XCTAssertEqual(
            ParkingTimelinePolicy.cadence(
                now: now,
                meterExpiry: now.addingTimeInterval(3600),
                lowPowerMode: false
            ),
            60
        )
    }

    func testUrgentAndRecentlyExpiredMetersUseOneSecondCadence() {
        XCTAssertEqual(
            ParkingTimelinePolicy.cadence(
                now: now,
                meterExpiry: now.addingTimeInterval(600),
                lowPowerMode: false
            ),
            1
        )
        XCTAssertEqual(
            ParkingTimelinePolicy.cadence(
                now: now,
                meterExpiry: now.addingTimeInterval(-600),
                lowPowerMode: false
            ),
            1
        )
    }

    func testLowPowerModeAlwaysUsesOneMinuteCadence() {
        XCTAssertEqual(
            ParkingTimelinePolicy.cadence(
                now: now,
                meterExpiry: now.addingTimeInterval(10),
                lowPowerMode: true
            ),
            60
        )
    }

    func testNoMeterUsesOneMinuteCadence() {
        XCTAssertEqual(
            ParkingTimelinePolicy.cadence(now: now, meterExpiry: nil, lowPowerMode: false),
            60
        )
    }

    func testParkedForDescriptionDoesNotDisplayStaleSeconds() {
        XCTAssertEqual(ParkingTimelinePolicy.elapsedDescription(15), "1 min")
        XCTAssertEqual(ParkingTimelinePolicy.elapsedDescription(3900), "1 hr 5 min")
    }

    func testReduceMotionRemovesProgressAnimationOnly() {
        XCTAssertNil(ParkingTimelinePolicy.progressAnimation(reduceMotion: true))
        XCTAssertEqual(
            ParkingTimelinePolicy.progressAnimation(reduceMotion: false),
            0.25
        )
    }

    func testUITestLowPowerOverrideIsScopedToUITesting() {
        XCTAssertTrue(
            ParkNudgePowerState.current(
                arguments: ["ParkNudge", "-ui-testing", "-ui-test-low-power-mode"],
                systemLowPowerMode: false
            )
        )
        XCTAssertFalse(
            ParkNudgePowerState.current(
                arguments: ["ParkNudge", "-ui-test-low-power-mode"],
                systemLowPowerMode: false
            )
        )
        XCTAssertTrue(
            ParkNudgePowerState.current(arguments: ["ParkNudge"], systemLowPowerMode: true)
        )
    }
}
