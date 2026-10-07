import XCTest
import UIKit
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

    func testStoringReplacementDoesNotOverwriteExistingPhoto() throws {
        let fixture = try makePhotoFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let id = UUID()
        let originalPath = try fixture.photos.storeJPEG(data: photoData(color: .black), sessionID: id)
        let originalData = try XCTUnwrap(fixture.photos.load(relativePath: originalPath))

        let replacementPath = try fixture.photos.storeJPEG(data: photoData(color: .white), sessionID: id)

        XCTAssertNotEqual(replacementPath, originalPath)
        XCTAssertEqual(fixture.photos.load(relativePath: originalPath), originalData)
        XCTAssertNotEqual(fixture.photos.load(relativePath: replacementPath), originalData)
        XCTAssertEqual(try photoPaths(in: fixture.root), Set([originalPath, replacementPath]))
    }

    func testFailedPhotoReplacementPreservesOriginalPhotoAndRecord() async throws {
        let fixture = try makePhotoFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let original = try seedLegacyPhoto(repository: fixture.repository, root: fixture.root)
        let originalData = try XCTUnwrap(fixture.photos.load(relativePath: try XCTUnwrap(original.photoRelativePath)))
        fixture.repository.failsUpdating = true
        var draft = ParkingDraft.editing(original)
        draft.photoData = photoData(color: .white)
        draft.note = "Unsaved change"

        do {
            _ = try await fixture.coordinator.updateActive(draft: draft, reminderOffsets: [])
            XCTFail("The injected persistence failure must reach the caller.")
        } catch {
            let saved = try XCTUnwrap(fixture.repository.activeSession())
            XCTAssertEqual(saved, original)
            XCTAssertEqual(fixture.photos.load(relativePath: try XCTUnwrap(saved.photoRelativePath)), originalData)
            XCTAssertEqual(try photoPaths(in: fixture.root), Set([try XCTUnwrap(original.photoRelativePath)]))
        }
    }

    func testSuccessfulPhotoReplacementRetiresOriginalOnlyAfterPersistence() async throws {
        let fixture = try makePhotoFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let original = try seedLegacyPhoto(repository: fixture.repository, root: fixture.root)
        var draft = ParkingDraft.editing(original)
        draft.photoData = photoData(color: .white)

        let outcome = try await fixture.coordinator.updateActive(draft: draft, reminderOffsets: [])

        let newPath = try XCTUnwrap(outcome.session.photoRelativePath)
        XCTAssertNotEqual(newPath, original.photoRelativePath)
        XCTAssertEqual(try fixture.repository.activeSession(), outcome.session)
        XCTAssertNotNil(fixture.photos.load(relativePath: newPath))
        XCTAssertNil(fixture.photos.load(relativePath: try XCTUnwrap(original.photoRelativePath)))
        XCTAssertEqual(try photoPaths(in: fixture.root), Set([newPath]))
    }

    func testFailedPhotoRemovalPreservesOriginalPhotoAndRecord() async throws {
        let fixture = try makePhotoFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let original = try seedLegacyPhoto(repository: fixture.repository, root: fixture.root)
        fixture.repository.failsUpdating = true
        var draft = ParkingDraft.editing(original)
        draft.removePhoto = true

        do {
            _ = try await fixture.coordinator.updateActive(draft: draft, reminderOffsets: [])
            XCTFail("The injected persistence failure must reach the caller.")
        } catch {
            XCTAssertEqual(try fixture.repository.activeSession(), original)
            XCTAssertNotNil(fixture.photos.load(relativePath: try XCTUnwrap(original.photoRelativePath)))
            XCTAssertEqual(try photoPaths(in: fixture.root), Set([try XCTUnwrap(original.photoRelativePath)]))
        }
    }

    func testSuccessfulPhotoRemovalDeletesOriginal() async throws {
        let fixture = try makePhotoFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let original = try seedLegacyPhoto(repository: fixture.repository, root: fixture.root)
        var draft = ParkingDraft.editing(original)
        draft.removePhoto = true

        let outcome = try await fixture.coordinator.updateActive(draft: draft, reminderOffsets: [])

        XCTAssertNil(outcome.session.photoRelativePath)
        XCTAssertEqual(try fixture.repository.activeSession(), outcome.session)
        XCTAssertTrue(try photoPaths(in: fixture.root).isEmpty)
    }

    func testFailedActiveLookupDoesNotLeaveNewPhotoOnDisk() async throws {
        let fixture = try makePhotoFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        fixture.repository.failsReadingActive = true
        var draft = ParkingDraft.fallback(currencyCode: "USD", coordinate: GeoCoordinate(latitude: 1, longitude: 2))
        draft.photoData = photoData(color: .black)

        do {
            _ = try await fixture.coordinator.saveNew(draft: draft, replacingActive: false, reminderOffsets: [])
            XCTFail("The injected lookup failure must reach the caller.")
        } catch {
            XCTAssertTrue(fixture.repository.sessions.isEmpty)
            XCTAssertTrue(try photoPaths(in: fixture.root).isEmpty)
        }
    }

    func testFailedCreateRemovesOnlyStagedPhoto() async throws {
        let fixture = try makePhotoFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let retainedPath = try fixture.photos.storeJPEG(data: photoData(color: .black), sessionID: UUID())
        fixture.repository.failsCreating = true
        var draft = ParkingDraft.fallback(currencyCode: "USD", coordinate: GeoCoordinate(latitude: 1, longitude: 2))
        draft.photoData = photoData(color: .white)

        do {
            _ = try await fixture.coordinator.saveNew(draft: draft, replacingActive: false, reminderOffsets: [])
            XCTFail("The injected persistence failure must reach the caller.")
        } catch {
            XCTAssertTrue(fixture.repository.sessions.isEmpty)
            XCTAssertEqual(try photoPaths(in: fixture.root), Set([retainedPath]))
        }
    }

    func testUnconfirmedReplacementPreservesOriginalSessionAndPhoto() async throws {
        let fixture = try makePhotoFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let original = try seedLegacyPhoto(repository: fixture.repository, root: fixture.root)
        var draft = ParkingDraft.fallback(currencyCode: "USD", coordinate: GeoCoordinate(latitude: 1, longitude: 2))
        draft.photoData = photoData(color: .white)

        do {
            _ = try await fixture.coordinator.saveNew(draft: draft, replacingActive: false, reminderOffsets: [])
            XCTFail("Replacing an active session requires confirmation.")
        } catch {
            XCTAssertEqual(error as? ParkingRepositoryError, .activeSessionExists)
            XCTAssertEqual(try fixture.repository.activeSession(), original)
            XCTAssertEqual(try photoPaths(in: fixture.root), Set([try XCTUnwrap(original.photoRelativePath)]))
        }
    }

    private func makePhotoFixture() throws -> (
        coordinator: ParkingCoordinator,
        repository: ModelParkingRepositoryFake,
        photos: ApplicationSupportPhotoStore,
        root: URL
    ) {
        let root = FileManager.default.temporaryDirectory.appending(path: "ParkNudgePhotoTests-\(UUID().uuidString)")
        let photos = try ApplicationSupportPhotoStore(rootURL: root)
        let repository = ModelParkingRepositoryFake()
        let coordinator = ParkingCoordinator(
            repository: repository, notifications: NotificationFake(), photos: photos,
            clock: FixedClock(now: TestFixtures.date)
        )
        return (coordinator, repository, photos, root)
    }

    /// Existing installs use the original session-only filename; retain compatibility.
    private func seedLegacyPhoto(repository: ModelParkingRepositoryFake, root: URL) throws -> ParkingSession {
        let id = UUID()
        let path = "Photos/\(id.uuidString.lowercased()).jpg"
        try photoData(color: .black).write(to: root.appending(path: path))
        let original = TestFixtures.session(id: id, photoRelativePath: path)
        try repository.create(original)
        return original
    }

    private func photoData(color: UIColor) -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        return image.jpegData(compressionQuality: 1) ?? Data()
    }

    private func photoPaths(in root: URL) throws -> Set<String> {
        let files = try FileManager.default.contentsOfDirectory(
            at: root.appending(path: "Photos"), includingPropertiesForKeys: nil
        )
        return Set(files.map { "Photos/\($0.lastPathComponent)" })
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
        let path = "Photos/\(sessionID.uuidString)-\(UUID().uuidString).jpg"
        self.data[path] = data
        return path
    }
    func load(relativePath: String) -> Data? { data[relativePath] }
    func delete(relativePath: String) throws { data[relativePath] = nil }
    func removeOrphans(keeping relativePaths: Set<String>) throws {
        data = data.filter { relativePaths.contains($0.key) }
    }
}
