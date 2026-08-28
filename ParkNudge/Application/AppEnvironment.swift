import Foundation
import SwiftData

@MainActor
struct AppEnvironment {
    let container: ModelContainer
    let model: AppModel

    static func make() throws -> AppEnvironment {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-testing") {
            return try makeUITesting(arguments: arguments)
        }
        return try makeLive()
    }

    private static func makeLive() throws -> AppEnvironment {
        let container = try ParkNudgeContainerFactory.make()
        let repository = SwiftDataParkingRepository(container: container)
        let photos = try ApplicationSupportPhotoStore()
        let notifications = LocalNotificationScheduler()
        let clock = SystemClock()
        let coordinator = ParkingCoordinator(
            repository: repository,
            notifications: notifications,
            photos: photos,
            clock: clock
        )
        let model = AppModel(
            repository: repository,
            coordinator: coordinator,
            location: OneShotLocationProvider(),
            directions: AppleMapsDirectionsOpener(),
            purchases: StoreKitPurchaseService(),
            exporter: LocalCSVExporter(),
            photos: photos,
            settings: AppSettings(),
            reviews: StoreKitReviewRequester(),
            clock: clock
        )
        return AppEnvironment(container: container, model: model)
    }

    private static func makeUITesting(arguments: [String]) throws -> AppEnvironment {
        let container = try ParkNudgeContainerFactory.make(inMemory: true)
        let repository = SwiftDataParkingRepository(container: container)
        let root = FileManager.default.temporaryDirectory
            .appending(path: "ParkNudgeUITests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let photos = try ApplicationSupportPhotoStore(rootURL: root)
        let notifications = UITestNotificationScheduler()
        let clock = SystemClock()
        let defaults = UserDefaults(suiteName: "ParkNudgeUITests") ?? .standard
        defaults.removePersistentDomain(forName: "ParkNudgeUITests")
        let settings = AppSettings(defaults: defaults)
        let purchases = UITestPurchaseProvider(isPro: arguments.contains("-ui-test-pro"))
        let coordinator = ParkingCoordinator(
            repository: repository,
            notifications: notifications,
            photos: photos,
            clock: clock
        )
        let model = AppModel(
            repository: repository,
            coordinator: coordinator,
            location: UITestLocationProvider(shouldFail: arguments.contains("-ui-test-location-denied")),
            directions: UITestDirectionsOpener(),
            purchases: purchases,
            exporter: LocalCSVExporter(rootURL: root.appending(path: "Exports")),
            photos: photos,
            settings: settings,
            reviews: UITestReviewRequester(),
            clock: clock
        )

        if let meterOffset = try UITestMeterSeed.offset(arguments: arguments) {
            try seedActiveMeteredSession(
                into: repository,
                clock: clock,
                meterOffset: meterOffset
            )
        }

        return AppEnvironment(container: container, model: model)
    }

    /// Seeds one active session with a running meter, for tests about the Park
    /// screen's *layout* rather than about the editor.
    ///
    /// Driving the editor to set a meter means tapping a `Form` `Toggle`, whose
    /// accessibility element spans the whole row — so the tap point has to be
    /// derived from the switch geometry, and that shifts between device sizes
    /// and text sizes. A layout test that fails because a synthetic tap missed
    /// a switch is telling you nothing about layout. Seeding removes the whole
    /// question. Only ever reachable under `-ui-testing`, against the in-memory
    /// container.
    private static func seedActiveMeteredSession(
        into repository: ParkingRepository,
        clock: Clock,
        meterOffset: TimeInterval
    ) throws {
        let now = clock.now
        try repository.create(
            ParkingSession(
                id: UUID(),
                startedAt: now.addingTimeInterval(-1_800),
                endedAt: nil,
                coordinate: GeoCoordinate(latitude: 40.741_895, longitude: -73.989_308),
                horizontalAccuracy: 8,
                locationLabel: "Union Square Garage",
                floor: "3",
                section: "14",
                note: nil,
                meterExpiresAt: now.addingTimeInterval(meterOffset),
                paidAmountMinor: nil,
                currencyCode: nil,
                source: .currentLocation,
                photoRelativePath: nil,
                createdAt: now.addingTimeInterval(-1_800),
                updatedAt: now.addingTimeInterval(-1_800)
            )
        )
    }
}

/// Swallows the request so a UI-test run can never put the system rating
/// prompt on screen, where it would steal the tap the test was aiming at.
@MainActor
private final class UITestReviewRequester: ReviewRequesting {
    func requestReview() -> Bool { false }
}

@MainActor
private final class UITestLocationProvider: LocationProviding {
    let shouldFail: Bool

    init(shouldFail: Bool) { self.shouldFail = shouldFail }

    func captureCurrentLocation() async throws -> CapturedLocation {
        if shouldFail { throw LocationServiceError.denied }
        return CapturedLocation(
            coordinate: GeoCoordinate(latitude: 40.741_895, longitude: -73.989_308),
            horizontalAccuracy: 8,
            capturedAt: Date(),
            isReducedAccuracy: false
        )
    }
}

@MainActor
private final class UITestNotificationScheduler: NotificationScheduling {
    func requestAuthorizationIfNeeded() async throws -> Bool { true }
    func schedule(_ reminders: [ReminderPlan], expiry: Date) async throws {}
    func cancel(identifiers: [String]) async {}
    func authorizationAllowsAlerts() async -> Bool { true }
}

@MainActor
private final class UITestDirectionsOpener: DirectionsOpening {
    func openWalkingDirections(to coordinate: GeoCoordinate, label: String?) throws {}
}

@MainActor
private final class UITestPurchaseProvider: PurchaseProviding {
    private var isPro: Bool

    init(isPro: Bool) { self.isPro = isPro }

    func loadProduct() async -> PurchaseProduct? {
        PurchaseProduct(
            identifier: StoreKitPurchaseService.productIdentifier,
            displayName: "ParkNudge Lifetime Pro",
            displayPrice: "$9.99"
        )
    }

    func currentEntitlement() async -> EntitlementState { isPro ? .pro : .free }

    func purchase() async throws -> PurchaseOutcome {
        isPro = true
        return .purchased
    }

    func restore() async throws -> EntitlementState { isPro ? .pro : .free }

    func entitlementUpdates() -> AsyncStream<EntitlementState> {
        AsyncStream { _ in }
    }
}
