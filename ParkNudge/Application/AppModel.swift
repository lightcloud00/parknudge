import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var activeSession: ParkingSession?
    @Published private(set) var completedSessions: [ParkingSession] = []
    @Published private(set) var entitlement: EntitlementState = .loading
    @Published private(set) var lifetimeProduct: PurchaseProduct?
    @Published private(set) var isBusy = false
    @Published var alertMessage: String?
    @Published var isPaywallPresented = false
    @Published var requestedProFeature: ProFeature?

    let settings: AppSettings

    private let repository: ParkingRepository
    private let coordinator: ParkingCoordinator
    private let location: LocationProviding
    private let directions: DirectionsOpening
    private let purchases: PurchaseProviding
    private let exporter: CSVExporting
    private let photos: PhotoStoring
    private let clock: Clock
    private var entitlementTask: Task<Void, Never>?
    private var hasBootstrapped = false

    init(
        repository: ParkingRepository,
        coordinator: ParkingCoordinator,
        location: LocationProviding,
        directions: DirectionsOpening,
        purchases: PurchaseProviding,
        exporter: CSVExporting,
        photos: PhotoStoring,
        settings: AppSettings,
        clock: Clock
    ) {
        self.repository = repository
        self.coordinator = coordinator
        self.location = location
        self.directions = directions
        self.purchases = purchases
        self.exporter = exporter
        self.photos = photos
        self.settings = settings
        self.clock = clock
    }

    deinit {
        entitlementTask?.cancel()
    }

    var visibleHistory: [ParkingSession] {
        entitlement.isPro
            ? completedSessions
            : Array(completedSessions.prefix(FeatureAccessPolicy.freeHistoryLimit))
    }

    var hiddenHistoryCount: Int {
        max(0, completedSessions.count - visibleHistory.count)
    }

    func bootstrap() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        exporter.cleanupTemporaryExports()
        try? coordinator.cleanOrphanedPhotos()
        await reload()
        lifetimeProduct = await purchases.loadProduct()
        entitlement = await purchases.currentEntitlement()
        observeEntitlementUpdates()
    }

    func reload() async {
        do {
            activeSession = try repository.activeSession()
            completedSessions = try repository.completedSessions()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func newParkingDraft() async -> ParkingDraft {
        isBusy = true
        defer { isBusy = false }
        do {
            let captured = try await location.captureCurrentLocation()
            if captured.isReducedAccuracy {
                alertMessage = "Your location is approximate. Check and move the pin before saving."
            } else if clock.now.timeIntervalSince(captured.capturedAt) > 60 {
                alertMessage = "That location may be stale. Check and move the pin before saving."
            }
            return ParkingDraft(
                coordinate: captured.coordinate,
                horizontalAccuracy: captured.horizontalAccuracy,
                source: .currentLocation,
                currencyCode: settings.currencyCode,
                originalPhotoRelativePath: nil
            )
        } catch {
            return .fallback(
                currencyCode: settings.currencyCode,
                coordinate: GeoCoordinate(latitude: 39.8283, longitude: -98.5795)
            )
        }
    }

    func saveNew(draft: ParkingDraft, replacingActive: Bool) async -> Bool {
        var draft = draft
        if !hasAccess(to: .parkingCosts) {
            draft.paidAmountMinor = nil
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let result = try await coordinator.saveNew(
                draft: draft,
                replacingActive: replacingActive,
                reminderOffsets: reminderOffsets
            )
            await reload()
            alertMessage = result.notificationWarning
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }

    func updateActive(draft: ParkingDraft) async -> Bool {
        var draft = draft
        if !hasAccess(to: .parkingCosts) {
            draft.paidAmountMinor = activeSession?.paidAmountMinor
            draft.currencyCode = activeSession?.currencyCode ?? draft.currencyCode
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let result = try await coordinator.updateActive(
                draft: draft,
                reminderOffsets: reminderOffsets
            )
            await reload()
            alertMessage = result.notificationWarning
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }

    func finishActive() async {
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await coordinator.finishActive()
            await reload()
            if !entitlement.isPro,
               completedSessions.count == 1,
               !settings.didOfferFirstCompletionPaywall
            {
                settings.didOfferFirstCompletionPaywall = true
                requestedProFeature = nil
                isPaywallPresented = true
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func delete(_ session: ParkingSession) async {
        do {
            try await coordinator.delete(sessionID: session.id)
            await reload()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func deleteEverything() async -> Bool {
        isBusy = true
        defer { isBusy = false }
        do {
            try await coordinator.deleteAll()
            await reload()
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }

    func openDirections() {
        guard let activeSession else { return }
        do {
            try directions.openWalkingDirections(
                to: activeSession.coordinate,
                label: activeSession.locationLabel
            )
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func hasAccess(to feature: ProFeature) -> Bool {
        FeatureAccessPolicy.canUse(feature, entitlement: entitlement)
    }

    func requestAccess(to feature: ProFeature) {
        requestedProFeature = feature
        isPaywallPresented = true
    }

    /// `bootstrap()` loads the product exactly once, so a first launch that
    /// could not reach the App Store left the paywall permanently showing
    /// "Lifetime Pro Unavailable" with no way to try again for the rest of the
    /// process lifetime.
    func refreshLifetimeProduct() async {
        isBusy = true
        defer { isBusy = false }
        lifetimeProduct = await purchases.loadProduct()
        if lifetimeProduct == nil {
            alertMessage = "The App Store price is still unavailable. Free parking features are unaffected."
        }
    }

    func purchaseLifetime() async {
        isBusy = true
        defer { isBusy = false }
        do {
            switch try await purchases.purchase() {
            case .purchased:
                entitlement = await purchases.currentEntitlement()
                if entitlement.isPro {
                    isPaywallPresented = false
                    alertMessage = "Lifetime Pro is unlocked."
                }
            case .cancelled:
                break
            case .pending:
                alertMessage = "Your purchase is pending approval. Free features remain available."
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isBusy = true
        defer { isBusy = false }
        do {
            entitlement = try await purchases.restore()
            alertMessage = entitlement.isPro
                ? "Lifetime Pro was restored."
                : "No active Lifetime Pro purchase was found."
            if entitlement.isPro { isPaywallPresented = false }
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func makeCSVExport() -> URL? {
        guard hasAccess(to: .csvExport) else {
            requestAccess(to: .csvExport)
            return nil
        }
        do {
            return try exporter.makeExport(sessions: completedSessions)
        } catch {
            alertMessage = error.localizedDescription
            return nil
        }
    }

    func cleanupTemporaryExports() {
        exporter.cleanupTemporaryExports()
    }

    func photoData(for session: ParkingSession) -> Data? {
        guard let path = session.photoRelativePath else { return nil }
        return photos.load(relativePath: path)
    }

    private var reminderOffsets: [Int] {
        entitlement.isPro ? settings.customReminderOffsets : ReminderPlanner.freeOffsets
    }

    private func observeEntitlementUpdates() {
        entitlementTask?.cancel()
        entitlementTask = Task { [weak self] in
            guard let self else { return }
            for await state in purchases.entitlementUpdates() {
                entitlement = state
            }
        }
    }
}
