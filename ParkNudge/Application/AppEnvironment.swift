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
            clock: clock
        )
        return AppEnvironment(container: container, model: model)
    }
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
