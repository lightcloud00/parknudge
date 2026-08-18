import XCTest
@testable import ParkNudge

@MainActor
final class ParkingCoordinatorTests: XCTestCase {
    func testNotificationFailureDoesNotDiscardSession() async throws {
        let container = try ParkNudgeContainerFactory.make(inMemory: true)
        let repository = SwiftDataParkingRepository(container: container)
        let notifications = NotificationFake(scheduleError: TestError.failed)
        let photos = PhotoStoreFake()
        let coordinator = ParkingCoordinator(
            repository: repository,
            notifications: notifications,
            photos: photos,
            clock: FixedClock(now: TestFixtures.date)
        )
        var draft = ParkingDraft.fallback(
            currencyCode: "USD",
            coordinate: GeoCoordinate(latitude: 1, longitude: 2)
        )
        draft.meterExpiresAt = TestFixtures.date.addingTimeInterval(1_800)

        let outcome = try await coordinator.saveNew(
            draft: draft,
            replacingActive: false,
            reminderOffsets: ReminderPlanner.freeOffsets
        )

        XCTAssertNotNil(try repository.activeSession())
        XCTAssertNotNil(outcome.notificationWarning)
    }

    func testEditingMeterCancelsOldIdentifiersAndReplacesRequests() async throws {
        let container = try ParkNudgeContainerFactory.make(inMemory: true)
        let repository = SwiftDataParkingRepository(container: container)
        let notifications = NotificationFake()
        let coordinator = ParkingCoordinator(
            repository: repository,
            notifications: notifications,
            photos: PhotoStoreFake(),
            clock: FixedClock(now: TestFixtures.date)
        )
        var draft = ParkingDraft.fallback(
            currencyCode: "USD",
            coordinate: GeoCoordinate(latitude: 1, longitude: 2)
        )
        draft.meterExpiresAt = TestFixtures.date.addingTimeInterval(3_600)
        _ = try await coordinator.saveNew(
            draft: draft,
            replacingActive: false,
            reminderOffsets: [15, 5, 0]
        )
        let active = try XCTUnwrap(repository.activeSession())
        let oldIdentifiers = Set(try repository.reminders(sessionID: active.id).map(\.notificationIdentifier))

        var edit = ParkingDraft.editing(active)
        edit.meterExpiresAt = TestFixtures.date.addingTimeInterval(7_200)
        _ = try await coordinator.updateActive(draft: edit, reminderOffsets: [30, 0])

        XCTAssertTrue(oldIdentifiers.isSubset(of: Set(notifications.cancelled)))
        XCTAssertEqual(try repository.reminders(sessionID: active.id).map(\.offsetMinutes), [30, 0])
    }
}

private enum TestError: Error { case failed }

@MainActor
private final class NotificationFake: NotificationScheduling {
    let scheduleError: Error?
    var cancelled: [String] = []

    init(scheduleError: Error? = nil) { self.scheduleError = scheduleError }
    func requestAuthorizationIfNeeded() async throws -> Bool { true }
    func schedule(_ reminders: [ReminderPlan], expiry: Date) async throws {
        if let scheduleError { throw scheduleError }
    }
    func cancel(identifiers: [String]) async { cancelled.append(contentsOf: identifiers) }
    func authorizationAllowsAlerts() async -> Bool { true }
}

@MainActor
private final class PhotoStoreFake: PhotoStoring {
    var data: [String: Data] = [:]
    func storeJPEG(data: Data, sessionID: UUID) throws -> String {
        let path = "Photos/\(sessionID.uuidString).jpg"
        self.data[path] = data
        return path
    }
    func load(relativePath: String) -> Data? { data[relativePath] }
    func delete(relativePath: String) throws { data[relativePath] = nil }
    func removeOrphans(keeping relativePaths: Set<String>) throws {
        data = data.filter { relativePaths.contains($0.key) }
    }
}
