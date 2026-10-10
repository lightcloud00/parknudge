import Foundation
@testable import ParkNudge

enum TestFixtures {
    static let date = Date(timeIntervalSince1970: 1_700_000_000)

    static func session(
        id: UUID = UUID(),
        startedAt: Date = date,
        endedAt: Date? = nil,
        meterExpiresAt: Date? = nil,
        photoRelativePath: String? = nil
    ) -> ParkingSession {
        ParkingSession(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            coordinate: GeoCoordinate(latitude: 40.741_895, longitude: -73.989_308),
            horizontalAccuracy: 7.5,
            locationLabel: "Test Garage",
            floor: "3",
            section: "Blue",
            note: "Near elevator, \"north\" side",
            meterExpiresAt: meterExpiresAt,
            paidAmountMinor: 1_250,
            currencyCode: "USD",
            source: .currentLocation,
            photoRelativePath: photoRelativePath,
            createdAt: startedAt,
            updatedAt: endedAt ?? startedAt
        )
    }
}

struct FixedClock: Clock {
    let now: Date
}


extension TestFixtures {
    @MainActor
    static func appModel(completedSessions: Int = 0) throws -> AppModelHarness {
        try AppModelHarness(completedSessions: completedSessions)
    }
}

/// In-memory application composition; no system permissions, StoreKit, or disk I/O.
@MainActor
final class AppModelHarness {
    let repository = ModelParkingRepositoryFake()
    let location = ModelLocationFake()
    let notifications = ModelNotificationFake()
    let photos = ModelPhotoFake()
    let directions = ModelDirectionsFake()
    let purchases = ModelPurchaseFake()
    let exporter = ModelExportFake()
    let reviews = ModelReviewFake()
    let settings: AppSettings
    let model: AppModel
    private let defaults: UserDefaults
    private let suiteName = "ParkNudgeAppModelTests.\(UUID().uuidString)"

    init(completedSessions: Int) throws {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw ModelHarnessError.unavailableDefaults
        }
        self.defaults = defaults
        settings = AppSettings(defaults: defaults)
        let clock = FixedClock(now: TestFixtures.date)
        for index in 0..<completedSessions {
            let endedAt = TestFixtures.date.addingTimeInterval(Double(-index - 1))
            try repository.create(TestFixtures.session(endedAt: endedAt))
        }
        let coordinator = ParkingCoordinator(
            repository: repository, notifications: notifications, photos: photos, clock: clock
        )
        model = AppModel(
            repository: repository, coordinator: coordinator, location: location,
            directions: directions, purchases: purchases, exporter: exporter,
            photos: photos, settings: settings, reviews: reviews, clock: clock,
            marketingVersionProvider: { "1.0-test" }
        )
    }

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func completeParking() async throws {
        try repository.create(TestFixtures.session())
        await model.reload()
        await model.finishActive()
    }
}

private enum ModelHarnessError: Error { case unavailableDefaults, injectedFailure }

@MainActor
final class ModelParkingRepositoryFake: ParkingRepository {
    var sessions: [UUID: ParkingSession] = [:]
    var storedReminders: [UUID: [StoredReminder]] = [:]
    var failsFinishing = false
    var failsReadingActive = false
    var failsCreating = false
    var failsUpdating = false

    func activeSession() throws -> ParkingSession? {
        if failsReadingActive { throw ModelHarnessError.injectedFailure }
        return sessions.values.first { $0.endedAt == nil }
    }
    func completedSessions() throws -> [ParkingSession] {
        sessions.values.filter { $0.endedAt != nil }.sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }
    }
    func create(_ session: ParkingSession) throws {
        if failsCreating { throw ModelHarnessError.injectedFailure }
        if session.endedAt == nil, try activeSession() != nil {
            throw ParkingRepositoryError.activeSessionExists
        }
        sessions[session.id] = session
    }
    func replaceActive(with session: ParkingSession, at date: Date) throws -> ParkingSession? {
        var previous = try activeSession()
        if var archived = previous {
            archived.endedAt = date
            archived.updatedAt = date
            sessions[archived.id] = archived
            previous = archived
        }
        try create(session)
        return previous
    }
    func update(_ session: ParkingSession) throws {
        if failsUpdating { throw ModelHarnessError.injectedFailure }
        guard sessions[session.id] != nil else { throw ParkingRepositoryError.sessionNotFound }
        sessions[session.id] = session
    }
    func finish(sessionID: UUID, at date: Date) throws {
        if failsFinishing { throw ModelHarnessError.injectedFailure }
        guard var session = sessions[sessionID] else { throw ParkingRepositoryError.sessionNotFound }
        session.endedAt = date
        session.updatedAt = date
        sessions[sessionID] = session
    }
    func delete(sessionID: UUID) throws -> ParkingSession? {
        storedReminders[sessionID] = nil
        return sessions.removeValue(forKey: sessionID)
    }
    func deleteAll() throws -> [ParkingSession] {
        let removed = Array(sessions.values)
        sessions.removeAll()
        storedReminders.removeAll()
        return removed
    }
    func reminders(sessionID: UUID) throws -> [StoredReminder] { storedReminders[sessionID] ?? [] }
    func replaceReminders(sessionID: UUID, with reminders: [StoredReminder]) throws {
        storedReminders[sessionID] = reminders
    }
}

@MainActor
final class ModelLocationFake: LocationProviding {
    func captureCurrentLocation() async throws -> CapturedLocation {
        CapturedLocation(coordinate: GeoCoordinate(latitude: 40, longitude: -74),
                         horizontalAccuracy: 5, capturedAt: TestFixtures.date, isReducedAccuracy: false)
    }
}

@MainActor
final class ModelNotificationFake: NotificationScheduling {
    var cancelled: [String] = []
    var scheduled: [ReminderPlan] = []
    func requestAuthorizationIfNeeded() async throws -> Bool { true }
    func schedule(_ reminders: [ReminderPlan], expiry: Date) async throws { scheduled += reminders }
    func cancel(identifiers: [String]) async { cancelled += identifiers }
    func authorizationAllowsAlerts() async -> Bool { true }
}

@MainActor
final class ModelPhotoFake: PhotoStoring {
    var images: [String: Data] = [:]
    var loadCount = 0
    func storeJPEG(data: Data, sessionID: UUID) throws -> String {
        let path = "Photos/\(sessionID.uuidString)-\(UUID().uuidString).jpg"
        images[path] = data
        return path
    }
    func load(relativePath: String) -> Data? {
        loadCount += 1
        return images[relativePath]
    }
    func delete(relativePath: String) throws { images[relativePath] = nil }
    func removeOrphans(keeping relativePaths: Set<String>) throws {
        images = images.filter { relativePaths.contains($0.key) }
    }
}

@MainActor
final class ModelDirectionsFake: DirectionsOpening {
    func openWalkingDirections(to coordinate: GeoCoordinate, label: String?) throws {}
}

@MainActor
final class ModelPurchaseFake: PurchaseProviding {
    var entitlement: EntitlementState = .free
    var legacyAccess = true
    var legacyVerification: LegacyParkingAccessState?
    var refreshedLegacyVerification: LegacyParkingAccessState?
    private(set) var legacyRefreshCalls = 0
    var outcome: PurchaseOutcome = .cancelled
    var restoreFails = false
    /// When set, `currentEntitlement()` suspends until the legacy lookup has
    /// started, so it only returns if launch runs the two lookups together.
    var entitlementWaitsForLegacyLookup = false
    private var legacyLookupStarted = false
    private var entitlementWaiter: CheckedContinuation<Void, Never>?
    private let updates: AsyncStream<EntitlementState>
    private let updatesContinuation: AsyncStream<EntitlementState>.Continuation
    init() {
        (updates, updatesContinuation) = AsyncStream.makeStream()
    }
    func hasLegacyParkingAccess() async -> Bool { legacyAccess }
    func legacyParkingAccessState(refresh: Bool) async -> LegacyParkingAccessState {
        legacyLookupStarted = true
        entitlementWaiter?.resume()
        entitlementWaiter = nil
        if refresh {
            legacyRefreshCalls += 1
            if let refreshedLegacyVerification { return refreshedLegacyVerification }
        }
        return legacyVerification ?? (legacyAccess ? .eligible : .ineligible)
    }
    func loadProduct() async -> PurchaseProduct? { nil }
    func currentEntitlement() async -> EntitlementState {
        if entitlementWaitsForLegacyLookup && !legacyLookupStarted {
            await withCheckedContinuation { entitlementWaiter = $0 }
        }
        return entitlement
    }
    func purchase() async throws -> PurchaseOutcome { outcome }
    func restore() async throws -> EntitlementState {
        if restoreFails { throw PurchaseServiceError.storeUnavailable }
        return entitlement
    }
    func entitlementUpdates() -> AsyncStream<EntitlementState> { updates }
    func sendEntitlementUpdate(_ state: EntitlementState) {
        entitlement = state
        updatesContinuation.yield(state)
    }
}

@MainActor
final class ModelExportFake: CSVExporting {
    func makeExport(sessions: [ParkingSession]) throws -> URL {
        URL(fileURLWithPath: "/unused-test-export.csv")
    }
    func cleanupTemporaryExports() {}
}

@MainActor
final class ModelReviewFake: ReviewRequesting {
    var allowsInvocation = true
    private(set) var calls = 0
    func requestReview() -> Bool {
        calls += 1
        return allowsInvocation
    }
}
