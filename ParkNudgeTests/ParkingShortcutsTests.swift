import AppIntents
import XCTest
@testable import ParkNudge

@MainActor
final class ParkingShortcutsTests: XCTestCase {
    override func setUp() async throws {
        _ = ParkingShortcutInbox.shared.take()
    }

    func testBothShortcutsOnlyOpenTheApp() {
        XCTAssertTrue(ParkHereIntent.openAppWhenRun)
        XCTAssertTrue(FindMyCarIntent.openAppWhenRun)
    }

    func testParkHereQueuesTheSaveSpotRoute() async throws {
        _ = try await ParkHereIntent().perform()
        XCTAssertEqual(ParkingShortcutInbox.shared.take(), .parkHere)
    }

    func testFindMyCarQueuesTheDirectionsRoute() async throws {
        _ = try await FindMyCarIntent().perform()
        XCTAssertEqual(ParkingShortcutInbox.shared.take(), .findMyCar)
    }

    func testTakingARouteClearsItSoItRunsOnce() {
        ParkingShortcutInbox.shared.enqueue(.findMyCar)
        XCTAssertEqual(ParkingShortcutInbox.shared.take(), .findMyCar)
        XCTAssertNil(ParkingShortcutInbox.shared.take())
    }

    func testTheLatestRouteWins() {
        ParkingShortcutInbox.shared.enqueue(.parkHere)
        ParkingShortcutInbox.shared.enqueue(.findMyCar)
        XCTAssertEqual(ParkingShortcutInbox.shared.take(), .findMyCar)
    }

    func testProviderOffersExactlyTheTwoShortcuts() {
        XCTAssertEqual(ParkNudgeShortcuts.appShortcuts.count, 2)
    }
}
