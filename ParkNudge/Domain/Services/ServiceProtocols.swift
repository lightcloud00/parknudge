import Foundation

protocol Clock: Sendable {
    var now: Date { get }
}
struct SystemClock: Clock {
    var now: Date { Date() }
}

@MainActor
protocol ParkingRepository: AnyObject {
    func activeSession() throws -> ParkingSession?
    func completedSessions() throws -> [ParkingSession]
    func create(_ session: ParkingSession) throws
    func replaceActive(with session: ParkingSession, at date: Date) throws -> ParkingSession?
    func update(_ session: ParkingSession) throws
    func finish(sessionID: UUID, at date: Date) throws
    func delete(sessionID: UUID) throws -> ParkingSession?
    func deleteAll() throws -> [ParkingSession]
    func reminders(sessionID: UUID) throws -> [StoredReminder]
    func replaceReminders(sessionID: UUID, with reminders: [StoredReminder]) throws
}

@MainActor
protocol LocationProviding: AnyObject {
    func captureCurrentLocation() async throws -> CapturedLocation
}

@MainActor
protocol NotificationScheduling: AnyObject {
    func requestAuthorizationIfNeeded() async throws -> Bool
    func schedule(_ reminders: [ReminderPlan], expiry: Date) async throws
    func cancel(identifiers: [String]) async
    func authorizationAllowsAlerts() async -> Bool
}

@MainActor
protocol PhotoStoring: AnyObject {
    func storeJPEG(data: Data, sessionID: UUID) throws -> String
    func load(relativePath: String) -> Data?
    func delete(relativePath: String) throws
    func removeOrphans(keeping relativePaths: Set<String>) throws
}

@MainActor
protocol DirectionsOpening: AnyObject {
    func openWalkingDirections(to coordinate: GeoCoordinate, label: String?) throws
}

@MainActor
protocol PurchaseProviding: AnyObject {
    func loadProduct() async -> PurchaseProduct?
    func currentEntitlement() async -> EntitlementState
    func purchase() async throws -> PurchaseOutcome
    func restore() async throws -> EntitlementState
    func entitlementUpdates() -> AsyncStream<EntitlementState>
}

@MainActor
protocol CSVExporting: AnyObject {
    func makeExport(sessions: [ParkingSession]) throws -> URL
    func cleanupTemporaryExports()
}

/// Asks the system to consider showing its rating prompt.
///
/// Returns whether the adapter actually invoked StoreKit in a foreground key
/// window scene. This is not evidence that Apple displayed the prompt.
@MainActor
protocol ReviewRequesting: AnyObject {
    @discardableResult func requestReview() -> Bool
}
