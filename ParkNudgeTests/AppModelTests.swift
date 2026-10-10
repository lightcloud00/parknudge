import Combine
import UIKit
import XCTest
@testable import ParkNudge

@MainActor
final class AppModelTests: XCTestCase {
    func testFirstTwoCompletionsStayFreeAndThirdRequestsOnce() async throws {
        let harness = try TestFixtures.appModel()
        defer { harness.cleanup() }
        await harness.model.bootstrap()
        for count in 1...4 {
            try await harness.completeParking()
            XCTAssertNil(harness.model.activeSession)
            XCTAssertEqual(harness.model.completedSessions.count, count)
            XCTAssertFalse(harness.model.isPaywallPresented)
            XCTAssertEqual(harness.reviews.calls, count < 3 ? 0 : 1)
        }
        XCTAssertEqual(harness.settings.lastReviewRequestVersion, "1.0-test")
        XCTAssertEqual(harness.settings.lastReviewRequestDate, TestFixtures.date)
    }

    func testPaywallAndAlertEachSuppressWithoutConsumingVersion() async throws {
        for paywall in [true, false] {
            let harness = try TestFixtures.appModel(completedSessions: 2)
            defer { harness.cleanup() }
            harness.model.isPaywallPresented = paywall
            harness.model.alertMessage = paywall ? nil : "An existing error"
            try await harness.completeParking()
            XCTAssertEqual(harness.model.completedSessions.count, 3)
            XCTAssertEqual(harness.reviews.calls, 0)
            XCTAssertNil(harness.settings.lastReviewRequestVersion)
            XCTAssertNil(harness.settings.lastReviewRequestDate)

            harness.model.isPaywallPresented = false
            harness.model.alertMessage = nil
            try await harness.completeParking()
            XCTAssertEqual(harness.reviews.calls, 1)
        }
    }

    func testFailedFinishKeepsActiveSessionAndNeverRequestsReview() async throws {
        let harness = try TestFixtures.appModel(completedSessions: 2)
        defer { harness.cleanup() }
        harness.repository.failsFinishing = true
        try await harness.completeParking()
        XCTAssertNotNil(harness.model.activeSession)
        XCTAssertEqual(harness.model.completedSessions.count, 2)
        XCTAssertNotNil(harness.model.alertMessage)
        XCTAssertEqual(harness.reviews.calls, 0)
        XCTAssertNil(harness.settings.lastReviewRequestVersion)
    }

    func testDeclinedAdapterDoesNotConsumeVersionOrCooldown() async throws {
        let harness = try TestFixtures.appModel(completedSessions: 2)
        defer { harness.cleanup() }
        harness.reviews.allowsInvocation = false
        try await harness.completeParking()
        XCTAssertEqual(harness.reviews.calls, 1)
        XCTAssertNil(harness.settings.lastReviewRequestVersion)
        XCTAssertNil(harness.settings.lastReviewRequestDate)
        harness.reviews.allowsInvocation = true
        try await harness.completeParking()
        XCTAssertEqual(harness.reviews.calls, 2)
        XCTAssertEqual(harness.settings.lastReviewRequestVersion, "1.0-test")
    }

    func testSaveAndFinishPreserveMeterDeadlineWithoutRequestingEarly() async throws {
        let harness = try TestFixtures.appModel()
        defer { harness.cleanup() }
        await harness.model.bootstrap()
        var draft = await harness.model.newParkingDraft()
        let deadline = TestFixtures.date.addingTimeInterval(3600)
        draft.meterExpiresAt = deadline
        let saved = await harness.model.saveNew(draft: draft, replacingActive: false)
        XCTAssertTrue(saved)
        XCTAssertEqual(harness.model.activeSession?.meterExpiresAt, deadline)
        XCTAssertFalse(harness.notifications.scheduled.isEmpty)
        XCTAssertEqual(harness.reviews.calls, 0)
        await harness.model.finishActive()
        XCTAssertNil(harness.model.activeSession)
        XCTAssertEqual(harness.model.completedSessions.first?.meterExpiresAt, deadline)
        XCTAssertEqual(harness.model.completedSessions.first?.endedAt, TestFixtures.date)
        XCTAssertFalse(harness.notifications.cancelled.isEmpty)
    }

    func testUpdatedPhotoRetiresCachedThumbnail() throws {
        let harness = try TestFixtures.appModel()
        defer { harness.cleanup() }
        let path = "Photos/replaced.jpg"
        var session = TestFixtures.session(photoRelativePath: path)
        harness.photos.images[path] = imageData(color: .black)
        let original = try XCTUnwrap(harness.model.thumbnail(for: session))
        _ = harness.model.thumbnail(for: session)
        XCTAssertEqual(harness.photos.loadCount, 1)
        harness.photos.images[path] = imageData(color: .white)
        session.updatedAt = session.updatedAt.addingTimeInterval(1)
        let replacement = try XCTUnwrap(harness.model.thumbnail(for: session))
        XCTAssertEqual(harness.photos.loadCount, 2)
        XCTAssertNotEqual(original.pngData(), replacement.pngData())
    }

    func testNewCustomerCannotSaveOrReplaceBeforeVerifiedPurchase() async throws {
        let harness = try TestFixtures.appModel()
        defer { harness.cleanup() }
        harness.purchases.legacyAccess = false
        await harness.model.bootstrap()
        let draft = await harness.model.newParkingDraft()
        let saved = await harness.model.saveNew(draft: draft, replacingActive: false)
        XCTAssertFalse(saved)
        XCTAssertTrue(harness.model.isPaywallPresented)
        XCTAssertTrue(harness.model.requestedParkingAccess)
        XCTAssertTrue(harness.repository.sessions.isEmpty)
        XCTAssertTrue(harness.notifications.scheduled.isEmpty)

        let original = TestFixtures.session()
        try harness.repository.create(original)
        await harness.model.reload()
        harness.model.isPaywallPresented = false
        let replaced = await harness.model.saveNew(draft: draft, replacingActive: true)
        XCTAssertFalse(replaced)
        XCTAssertEqual(harness.model.activeSession?.id, original.id)
        XCTAssertEqual(harness.repository.sessions.count, 1)
        XCTAssertTrue(harness.model.completedSessions.isEmpty)
    }

    func testCancelledPendingAndUnverifiedPurchaseKeepParkingLocked() async throws {
        for outcome in [PurchaseOutcome.cancelled, .pending, .purchased] {
            let harness = try TestFixtures.appModel()
            defer { harness.cleanup() }
            harness.purchases.legacyAccess = false
            harness.purchases.outcome = outcome
            await harness.model.bootstrap()
            XCTAssertFalse(harness.model.requestNewParkingAccess())
            await harness.model.purchaseLifetime()
            XCTAssertFalse(harness.model.canStartParking)
            XCTAssertTrue(harness.model.isPaywallPresented)
            XCTAssertTrue(harness.repository.sessions.isEmpty)
        }
    }

    func testVerifiedPurchaseUnlocksAndRevocationBlocksOnlyNewParking() async throws {
        let harness = try TestFixtures.appModel()
        defer { harness.cleanup() }
        harness.purchases.legacyAccess = false
        await harness.model.bootstrap()
        XCTAssertFalse(harness.model.requestNewParkingAccess())
        harness.purchases.entitlement = .pro
        harness.purchases.outcome = .purchased
        await harness.model.purchaseLifetime()
        XCTAssertTrue(harness.model.canStartParking)
        XCTAssertFalse(harness.model.isPaywallPresented)
        XCTAssertNil(harness.model.alertMessage, "Parking must resume without a competing success alert")
        let draft = await harness.model.newParkingDraft()
        let saved = await harness.model.saveNew(draft: draft, replacingActive: false)
        XCTAssertTrue(saved)
        let id = harness.model.activeSession?.id
        harness.purchases.entitlement = .free
        await harness.model.restorePurchases()
        XCTAssertFalse(harness.model.canStartParking)
        XCTAssertEqual(harness.model.activeSession?.id, id)
        harness.model.openDirections()
        await harness.model.finishActive()
        XCTAssertNil(harness.model.activeSession)
        XCTAssertEqual(harness.model.completedSessions.first?.id, id)
    }

    func testLegacyCustomerKeepsParkingWithoutReceivingPro() async throws {
        let harness = try TestFixtures.appModel()
        defer { harness.cleanup() }
        await harness.model.bootstrap()
        XCTAssertTrue(harness.model.canStartParking)
        XCTAssertEqual(harness.model.entitlement, .free)
        XCTAssertFalse(harness.model.hasAccess(to: .parkingCosts))
    }

    func testUnknownLegacyOwnershipStaysLockedAndRestoreDoesNotClaimNoPurchase() async throws {
        let harness = try TestFixtures.appModel()
        defer { harness.cleanup() }
        harness.purchases.legacyVerification = .unknown
        await harness.model.bootstrap()
        XCTAssertEqual(harness.model.legacyParkingAccessState, .unknown)
        XCTAssertFalse(harness.model.canStartParking)
        XCTAssertFalse(harness.model.requestNewParkingAccess())
        await harness.model.restorePurchases()
        XCTAssertEqual(harness.purchases.legacyRefreshCalls, 1)
        XCTAssertFalse(harness.model.canStartParking)
        XCTAssertTrue(harness.model.isPaywallPresented)
        XCTAssertTrue(try XCTUnwrap(harness.model.alertMessage).contains("could not verify"))
        XCTAssertFalse(try XCTUnwrap(harness.model.alertMessage).contains("No previous"))
    }

    func testRestoreRecoversOriginalParkingEvenWhenPurchaseSyncFails() async throws {
        let harness = try TestFixtures.appModel()
        defer { harness.cleanup() }
        harness.purchases.legacyVerification = .unknown
        harness.purchases.refreshedLegacyVerification = .eligible
        harness.purchases.restoreFails = true
        await harness.model.bootstrap()
        XCTAssertFalse(harness.model.requestNewParkingAccess())
        await harness.model.restorePurchases()
        XCTAssertEqual(harness.purchases.legacyRefreshCalls, 1)
        XCTAssertTrue(harness.model.hasLegacyParkingAccess)
        XCTAssertTrue(harness.model.canStartParking)
        XCTAssertFalse(harness.model.entitlement.isPro)
        XCTAssertFalse(harness.model.hasAccess(to: .csvExport))
        XCTAssertFalse(harness.model.isPaywallPresented)
        XCTAssertNil(harness.model.alertMessage)
    }

    func testTemporaryLegacyVerificationFailurePreservesVerifiedOriginalAccess() async throws {
        let harness = try TestFixtures.appModel()
        defer { harness.cleanup() }
        await harness.model.bootstrap()
        harness.purchases.refreshedLegacyVerification = .unknown
        await harness.model.restorePurchases()
        XCTAssertTrue(harness.model.canStartParking)
        XCTAssertFalse(harness.model.entitlement.isPro)
        XCTAssertTrue(try XCTUnwrap(harness.model.alertMessage).contains("could not verify"))
    }

    func testFailedPurchaseRestoreConfirmsRecoveredOriginalAccessFromSettings() async throws {
        let harness = try TestFixtures.appModel()
        defer { harness.cleanup() }
        harness.purchases.legacyVerification = .unknown
        harness.purchases.refreshedLegacyVerification = .eligible
        harness.purchases.restoreFails = true
        await harness.model.bootstrap()
        harness.model.requestAccess(to: .customReminders)
        await harness.model.restorePurchases()
        XCTAssertTrue(harness.model.canStartParking)
        XCTAssertFalse(harness.model.entitlement.isPro)
        XCTAssertTrue(harness.model.isPaywallPresented, "Pro extras still require purchase")
        let message = try XCTUnwrap(harness.model.alertMessage)
        XCTAssertTrue(message.contains("original parking access was verified"))
        XCTAssertTrue(message.contains("could not restore Lifetime Pro"))
    }

    func testFailedPurchaseRestoreWithUnknownOwnershipDoesNotClaimVerifiedAccess() async throws {
        let harness = try TestFixtures.appModel()
        defer { harness.cleanup() }
        harness.purchases.legacyVerification = .unknown
        harness.purchases.restoreFails = true
        await harness.model.bootstrap()
        await harness.model.restorePurchases()
        XCTAssertFalse(harness.model.canStartParking)
        let message = try XCTUnwrap(harness.model.alertMessage)
        XCTAssertTrue(message.contains("could not verify your original parking access"))
        XCTAssertTrue(message.contains("could not restore Lifetime Pro"))
        XCTAssertFalse(message.contains("verified access remains available"))
    }

    func testVerifiedIneligibleRestoreCanReportNoPreviousAccess() async throws {
        let harness = try TestFixtures.appModel()
        defer { harness.cleanup() }
        harness.purchases.legacyAccess = false
        await harness.model.bootstrap()
        await harness.model.restorePurchases()
        XCTAssertFalse(harness.model.canStartParking)
        XCTAssertTrue(try XCTUnwrap(harness.model.alertMessage).contains("No previous"))
    }

    func testPendingApprovalDismissesActiveParkingOfferAfterVerifiedUpdate() async throws {
        let harness = try TestFixtures.appModel()
        defer { harness.cleanup() }
        harness.purchases.legacyAccess = false
        harness.purchases.outcome = .pending
        await harness.model.bootstrap()
        XCTAssertFalse(harness.model.requestNewParkingAccess())
        await harness.model.purchaseLifetime()
        XCTAssertFalse(harness.model.canStartParking)
        XCTAssertTrue(harness.model.isPaywallPresented)
        await sendEntitlementUpdate(.pro, in: harness)
        XCTAssertTrue(harness.model.canStartParking)
        XCTAssertFalse(harness.model.isPaywallPresented)
        XCTAssertTrue(harness.model.requestedParkingAccess)
        XCTAssertNil(harness.model.alertMessage)
        harness.model.paywallDidDismiss()
        XCTAssertFalse(harness.model.requestedParkingAccess)
        XCTAssertEqual(harness.model.paywallDismissalCount, 1)
        await sendEntitlementUpdate(.pro, in: harness)
        XCTAssertEqual(harness.model.paywallDismissalCount, 1)
    }

    func testLaterApprovalDoesNotReopenCancelledParkingIntent() async throws {
        let harness = try TestFixtures.appModel()
        defer { harness.cleanup() }
        harness.purchases.legacyAccess = false
        await harness.model.bootstrap()
        XCTAssertFalse(harness.model.requestNewParkingAccess())
        harness.model.isPaywallPresented = false
        harness.model.paywallDidDismiss()
        await sendEntitlementUpdate(.pro, in: harness)
        XCTAssertFalse(harness.model.isPaywallPresented)
        XCTAssertFalse(harness.model.requestedParkingAccess)
        XCTAssertEqual(harness.model.paywallDismissalCount, 1)
    }

    func testSettingsUpsellUsesPaidCoreForNewCustomersAndOriginalComparisonForLegacy() async throws {
        for legacy in [false, true] {
            let harness = try TestFixtures.appModel()
            defer { harness.cleanup() }
            harness.purchases.legacyAccess = legacy
            await harness.model.bootstrap()
            harness.model.requestAccess(to: .customReminders)
            XCTAssertEqual(harness.model.paywallRequiresParkingPurchase, !legacy)
            XCTAssertFalse(harness.model.requestedParkingAccess)
            await sendEntitlementUpdate(.pro, in: harness)
            XCTAssertFalse(harness.model.requestedParkingAccess)
            XCTAssertFalse(harness.model.isPaywallPresented)
        }
    }

    private func sendEntitlementUpdate(_ state: EntitlementState, in harness: AppModelHarness) async {
        let updated = expectation(description: "StoreKit entitlement update reaches model")
        let subscription = harness.model.$entitlement.dropFirst().first().sink { value in
            XCTAssertEqual(value, state)
            updated.fulfill()
        }
        harness.purchases.sendEntitlementUpdate(state)
        let result = await XCTWaiter.fulfillment(of: [updated], timeout: 2)
        XCTAssertEqual(result, .completed)
        withExtendedLifetime(subscription) {}
    }

    func testLegacyBuildBoundaryRejectsSandboxAndMalformedVersions() {
        for value in ["1", "2"] {
            XCTAssertTrue(LegacyParkingAccessPolicy.includes(originalBuild: value))
        }
        for value in ["", "0", "3", "1.0", "-1", " 2", "2 ", "２", "99999999999999999999999"] {
            XCTAssertFalse(LegacyParkingAccessPolicy.includes(originalBuild: value))
        }
    }

    private func imageData(color: UIColor) -> Data? {
        UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }.pngData()
    }
}

final class StoreDeadlineTests: XCTestCase {
    func testStalledStoreCallFailsClosedAtItsDeadline() async {
        let started = ContinuousClock.now
        do {
            // A detached sleep ignores the deadline's cancellation, like a
            // StoreKit call waiting on an abandoned App Store sign-in.
            _ = try await withStoreDeadline(seconds: 0.2) {
                await Task.detached { try? await Task.sleep(for: .seconds(5)) }.value
                return LegacyParkingAccessState.eligible
            }
            XCTFail("A stalled store call must not produce an access decision")
        } catch {
            XCTAssertEqual(error as? PurchaseServiceError, .storeUnavailable)
        }
        XCTAssertLessThan(started.duration(to: .now), .seconds(3))
    }

    func testPromptStoreResultPassesThrough() async throws {
        let state = try await withStoreDeadline(seconds: 5) { LegacyParkingAccessState.ineligible }
        XCTAssertEqual(state, .ineligible)
    }

    func testStoreErrorBeforeTheDeadlinePassesThrough() async {
        do {
            _ = try await withStoreDeadline(seconds: 5) { () throws -> Int in
                throw PurchaseServiceError.verificationFailed
            }
            XCTFail("The store error must reach the caller")
        } catch {
            XCTAssertEqual(error as? PurchaseServiceError, .verificationFailed)
        }
    }
}
