import Combine
import Foundation
import UIKit

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var activeSession: ParkingSession?
    @Published private(set) var completedSessions: [ParkingSession] = []
    @Published private(set) var entitlement: EntitlementState = .loading
    @Published private(set) var legacyParkingAccessState: LegacyParkingAccessState = .unknown
    @Published private(set) var hasCheckedParkingAccess = false
    @Published var requestedParkingAccess = false
    @Published private(set) var paywallDismissalCount = 0
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
    private let reviews: ReviewRequesting
    private let clock: Clock
    private let marketingVersionProvider: () -> String
    private var entitlementTask: Task<Void, Never>?
    private var hasBootstrapped = false
    private let thumbnailCache = NSCache<NSString, UIImage>()

    init(
        repository: ParkingRepository,
        coordinator: ParkingCoordinator,
        location: LocationProviding,
        directions: DirectionsOpening,
        purchases: PurchaseProviding,
        exporter: CSVExporting,
        photos: PhotoStoring,
        settings: AppSettings,
        // Deliberately not defaulted. A default argument here would construct a
        // `@MainActor` type from a nonisolated context — which the target's
        // settings happen to accept, but which makes every caller's dependency
        // implicit and trips any stricter check.
        reviews: ReviewRequesting,
        clock: Clock,
        marketingVersionProvider: (() -> String)? = nil
    ) {
        self.repository = repository
        self.coordinator = coordinator
        self.location = location
        self.directions = directions
        self.purchases = purchases
        self.exporter = exporter
        self.photos = photos
        self.settings = settings
        self.reviews = reviews
        self.clock = clock
        self.marketingVersionProvider = marketingVersionProvider ?? { Self.marketingVersion }
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
        // Both lookups gate a new customer's first park, so run them together:
        // a stalled store then costs one deadline before the offer, not two.
        let legacyLookup = Task { await purchases.legacyParkingAccessState(refresh: false) }
        entitlement = await purchases.currentEntitlement()
        observeEntitlementUpdates()
        applyLegacyParkingAccess(await legacyLookup.value)
        hasCheckedParkingAccess = true
        lifetimeProduct = await purchases.loadProduct()
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

    var hasLegacyParkingAccess: Bool { legacyParkingAccessState == .eligible }
    /// Paid parking access: verified Lifetime Pro or verified original-customer access.
    var canStartParking: Bool { entitlement.isPro || hasLegacyParkingAccess }
    var paywallRequiresParkingPurchase: Bool { !hasLegacyParkingAccess }
    var parkingSessionsStarted: Int {
        let saved = completedSessions.count + (activeSession == nil ? 0 : 1)
        return max(saved, settings.hasUsedFreeParkingSession ? ParkingStartPolicy.freeSessions : 0)
    }
    /// Paid access, or a new customer who has not used the free first parking session.
    var mayStartParking: Bool {
        ParkingStartPolicy.canStart(
            hasPaidParkingAccess: canStartParking,
            sessionsStarted: parkingSessionsStarted
        )
    }
    var freeParkingSessionsRemaining: Int? {
        ParkingStartPolicy.freeSessionsRemaining(
            hasPaidParkingAccess: canStartParking,
            sessionsStarted: parkingSessionsStarted
        )
    }

    @discardableResult
    func requestNewParkingAccess() -> Bool {
        guard mayStartParking else {
            if !hasCheckedParkingAccess {
                alertMessage = "Checking App Store access. Please try again in a moment."
            } else {
                requestedProFeature = nil
                requestedParkingAccess = true
                isPaywallPresented = true
            }
            return false
        }
        return true
    }

    func saveNew(draft: ParkingDraft, replacingActive: Bool) async -> Bool {
        // Recheck here as well as in the view: closing a paywall or losing an
        // entitlement while editing must never create or replace a session.
        guard requestNewParkingAccess() else { return false }
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
            settings.hasUsedFreeParkingSession = true
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
            considerRequestingReview()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    /// Considers asking for an App Store rating, after a session the user
    /// finished successfully.
    ///
    /// This call site follows a completed parking session and cannot overlap
    /// onboarding, a replacement confirmation, or a purchase operation. Those
    /// axes still live in the pure policy so future call sites cannot omit them.
    private func considerRequestingReview() {
        let version = marketingVersionProvider()
        let context = ReviewPromptContext(
            completedSessionCount: completedSessions.count,
            lastRequestedVersion: settings.lastReviewRequestVersion,
            lastRequestedDate: settings.lastReviewRequestDate,
            currentVersion: version,
            now: clock.now,
            hasActiveAlert: alertMessage != nil,
            hasActiveConfirmation: false,
            isPaywallPresented: isPaywallPresented,
            isPurchasePresented: false,
            // `finishActive` holds `isBusy` for its whole body, so this is read
            // as "is anything *else* in flight" from the policy's point of view.
            isBusy: false,
            isOnboardingPresented: false,
            isLaunchInProgress: false
        )
        guard ReviewPromptPolicy.shouldRequest(context) else { return }
        guard reviews.requestReview() else { return }
        settings.lastReviewRequestVersion = version
        settings.lastReviewRequestDate = clock.now
    }

    static var marketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
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

    func paywallDidDismiss() {
        requestedParkingAccess = false
        paywallDismissalCount += 1
    }

    func requestAccess(to feature: ProFeature) {
        requestedParkingAccess = false
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
            alertMessage = "The App Store price is still unavailable. Your saved spot and directions remain available."
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
                    // The parking entry intent resumes its editor after the
                    // offer dismisses. A simultaneous success alert competes
                    // for the same presentation and can discard that editor.
                    alertMessage = requestedParkingAccess ? nil : "Lifetime Pro is unlocked."
                }
            case .cancelled:
                break
            case .pending:
                alertMessage = "Your purchase is pending approval. New parking unlocks after verification. Your saved spot remains available."
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isBusy = true
        defer { isBusy = false }
        var purchaseRestoreFailed = false
        do {
            entitlement = try await purchases.restore()
        } catch {
            purchaseRestoreFailed = true
        }
        // Original app ownership has its own recovery path. An IAP sync
        // failure must not prevent the user from retrying that verification.
        let legacyResult = await purchases.legacyParkingAccessState(refresh: true)
        applyLegacyParkingAccess(legacyResult)
        hasCheckedParkingAccess = true
        if purchaseRestoreFailed {
            let accessMessage: String
            if legacyResult == .eligible {
                accessMessage = "Your original parking access was verified. "
            } else if canStartParking {
                accessMessage = "Your previously verified access remains available. "
            } else if legacyResult == .unknown {
                accessMessage = "The App Store could not verify your original parking access. "
            } else {
                accessMessage = ""
            }
            alertMessage = accessMessage + "The App Store could not restore Lifetime Pro. Try Restore Purchases again when the store is available. Your saved spot remains available."
        } else if entitlement.isPro {
            alertMessage = "Lifetime Pro was restored."
        } else if legacyResult == .unknown {
            alertMessage = "The App Store could not verify your original parking access. Try Restore Purchases again when the store is available. Your saved spot remains available."
        } else if hasLegacyParkingAccess {
            alertMessage = "Your original parking access was restored. Pro extras remain locked."
        } else {
            alertMessage = "No previous parking access or active Lifetime Pro purchase was found."
        }
        if entitlement.isPro || (requestedParkingAccess && hasLegacyParkingAccess) {
            if requestedParkingAccess { alertMessage = nil }
            isPaywallPresented = false
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

    /// A small square for History rows.
    ///
    /// Stored photos are up to 1600 px, and a `List` re-renders its rows
    /// freely, so decoding the full JPEG per row is not affordable. `updatedAt`
    /// is part of the key: replacing a photo reuses the same relative path but
    /// always bumps that date, which retires the stale entry without any
    /// separate invalidation.
    func thumbnail(for session: ParkingSession, edge: CGFloat = 120) -> UIImage? {
        guard let path = session.photoRelativePath else { return nil }
        let key = "\(path)@\(Int(edge))@\(session.updatedAt.timeIntervalSince1970)" as NSString
        if let cached = thumbnailCache.object(forKey: key) { return cached }
        guard let data = photos.load(relativePath: path), let source = UIImage(data: data) else {
            return nil
        }

        let side = CGSize(width: edge, height: edge)
        let rendered = UIGraphicsImageRenderer(size: side).image { _ in
            let scale = max(edge / max(source.size.width, 1), edge / max(source.size.height, 1))
            let filled = CGSize(width: source.size.width * scale, height: source.size.height * scale)
            source.draw(in: CGRect(
                x: (edge - filled.width) / 2,
                y: (edge - filled.height) / 2,
                width: filled.width,
                height: filled.height
            ))
        }
        thumbnailCache.setObject(rendered, forKey: key)
        return rendered
    }

    /// The offsets a meter saved right now would actually schedule. Exposed so
    /// the editor can show the real reminder times instead of describing them.
    var reminderOffsets: [Int] {
        entitlement.isPro ? settings.customReminderOffsets : ReminderPlanner.freeOffsets
    }

    private func observeEntitlementUpdates() {
        entitlementTask?.cancel()
        entitlementTask = Task { [weak self] in
            guard let updates = self?.purchases.entitlementUpdates() else { return }
            for await state in updates {
                guard let self else { return }
                self.entitlement = state
                if state.isPro && self.isPaywallPresented {
                    // A verified Ask to Buy update completes the still-open
                    // offer just like a synchronous purchase. ParkView consumes
                    // its saved intent once, after the sheet actually dismisses.
                    self.alertMessage = nil
                    self.isPaywallPresented = false
                }
            }
        }
    }

    private func applyLegacyParkingAccess(_ state: LegacyParkingAccessState) {
        // A transient store failure must not revoke an entitlement already
        // verified in this process. No preference or persisted cache grants it.
        if state != .unknown || !hasLegacyParkingAccess {
            legacyParkingAccessState = state
        }
    }
}
