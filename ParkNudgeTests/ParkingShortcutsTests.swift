import AppIntents
import XCTest
@testable import ParkNudge

/// The test host is the running app, and its `RootTabView` drains the shared inbox the moment a
/// route is enqueued. So the intents are checked by the route their notification carries, and the
/// inbox's own rules on a private instance the app does not observe.
@MainActor
final class ParkingShortcutsTests: XCTestCase {
    private func privateInbox() -> ParkingShortcutInbox {
        ParkingShortcutInbox(notificationCenter: NotificationCenter())
    }

    private func announcement(of route: ParkingShortcutRoute) -> XCTestExpectation {
        let expected = route.rawValue
        return expectation(forNotification: ParkingShortcutInbox.didEnqueue, object: nil) { note in
            note.userInfo?[ParkingShortcutInbox.routeKey] as? String == expected
        }
    }

    func testBothShortcutsOnlyOpenTheApp() {
        XCTAssertTrue(ParkHereIntent.openAppWhenRun)
        XCTAssertTrue(FindMyCarIntent.openAppWhenRun)
    }

    func testParkHereQueuesTheSaveSpotRoute() async throws {
        let announced = announcement(of: .parkHere)
        _ = try await ParkHereIntent().perform()
        await fulfillment(of: [announced], timeout: 2)
    }

    func testFindMyCarQueuesTheDirectionsRoute() async throws {
        let announced = announcement(of: .findMyCar)
        _ = try await FindMyCarIntent().perform()
        await fulfillment(of: [announced], timeout: 2)
    }

    func testTakingARouteClearsItSoItRunsOnce() {
        let inbox = privateInbox()
        inbox.enqueue(.findMyCar)
        XCTAssertEqual(inbox.take(), .findMyCar)
        XCTAssertNil(inbox.take())
    }

    func testTheLatestRouteWins() {
        let inbox = privateInbox()
        inbox.enqueue(.parkHere)
        inbox.enqueue(.findMyCar)
        XCTAssertEqual(inbox.take(), .findMyCar)
    }

    func testProviderOffersExactlyTheTwoShortcuts() {
        XCTAssertEqual(ParkNudgeShortcuts.appShortcuts.count, 2)
    }
}
