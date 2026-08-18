import SwiftData
import XCTest
@testable import ParkNudge

@MainActor
final class SwiftDataParkingRepositoryTests: XCTestCase {
    private var container: ModelContainer!
    private var repository: SwiftDataParkingRepository!

    override func setUpWithError() throws {
        container = try ParkNudgeContainerFactory.make(inMemory: true)
        repository = SwiftDataParkingRepository(container: container)
    }

    override func tearDown() {
        repository = nil
        container = nil
    }

    func testOneActiveSessionInvariant() throws {
        try repository.create(TestFixtures.session())
        XCTAssertThrowsError(try repository.create(TestFixtures.session())) { error in
            XCTAssertEqual(error as? ParkingRepositoryError, .activeSessionExists)
        }
        XCTAssertNotNil(try repository.activeSession())
    }

    func testReplacementArchivesExistingAndKeepsOneActive() throws {
        let first = TestFixtures.session()
        let replacement = TestFixtures.session(startedAt: TestFixtures.date.addingTimeInterval(600))
        try repository.create(first)

        let archived = try repository.replaceActive(
            with: replacement,
            at: TestFixtures.date.addingTimeInterval(600)
        )

        XCTAssertEqual(archived?.id, first.id)
        XCTAssertEqual(try repository.activeSession()?.id, replacement.id)
        XCTAssertEqual(try repository.completedSessions().map(\.id), [first.id])
    }

    func testNewRepositoryContextReadsPersistedContainerState() throws {
        let session = TestFixtures.session()
        try repository.create(session)

        let relaunchedRepository = SwiftDataParkingRepository(container: container)
        XCTAssertEqual(try relaunchedRepository.activeSession()?.id, session.id)
    }

    func testReminderReplacementAndDeleteCascade() throws {
        let session = TestFixtures.session(photoRelativePath: "Photos/test.jpg")
        try repository.create(session)
        let reminder = StoredReminder(
            id: UUID(),
            sessionID: session.id,
            fireDate: TestFixtures.date.addingTimeInterval(60),
            offsetMinutes: 0,
            notificationIdentifier: "test.reminder",
            createdAt: TestFixtures.date
        )
        try repository.replaceReminders(sessionID: session.id, with: [reminder])
        XCTAssertEqual(try repository.reminders(sessionID: session.id), [reminder])

        _ = try repository.delete(sessionID: session.id)
        let context = ModelContext(container)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ReminderRequestRecord>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PhotoMetadataRecord>()).count, 0)
    }
}
