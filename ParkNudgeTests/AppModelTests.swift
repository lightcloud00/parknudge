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
            // The first park was over a week ago (review_milestone.minimum_days).
            try await harness.completeParking(
                startedAt: count == 1 ? TestFixtures.date.addingTimeInterval(-8 * 24 * 60 * 60) : TestFixtures.date
            )
            XCTAssertNil(harness.model.activeSession)
            XCTAssertEqual(harness.model.completedSessions.count, count)
            XCTAssertFalse(harness.model.isPaywallPresented)
            XCTAssertEqual(harness.reviews.calls, count < 3 ? 0 : 1)
        }
        XCTAssertEqual(harness.settings.lastReviewRequestVersion, "1.0-test")
        XCTAssertEqual(harness.settings.lastReviewRequestDate, TestFixtures.date)
    }

    func testNoReviewRequestBeforeAWeekOfUse() async throws {
        let harness = try TestFixtures.appModel()
        defer { harness.cleanup() }
        await harness.model.bootstrap()
        for _ in 1...4 {
            try await harness.completeParking()
        }
        XCTAssertEqual(harness.model.completedSessions.count, 4)
        XCTAssertEqual(harness.reviews.calls, 0, "Four parks on day one are not a week of use.")
        XCTAssertNil(harness.settings.lastReviewRequestVersion)
    }

    func testNoReviewRequestInTheSameRunAsReachingTheFreeLimit() async throws {
        let harness = try TestFixtures.appModel(completedSessions: 2)
        defer { harness.cleanup() }
        await harness.model.bootstrap()
        XCTAssertNil(harness.model.makeCSVExport(), "CSV export is a Pro extra.")
        harness.model.isPaywallPresented = false

        try await harness.completeParking()
        XCTAssertEqual(harness.model.completedSessions.count, 3)
        XCTAssertEqual(harness.reviews.calls, 0)
        XCTAssertNil(harness.settings.lastReviewRequestVersion, "The skipped attempt must not consume the version.")
    }

    func testCSVExportPurchaseResumesWithoutACompetingAlert() async throws {
        let harness = try TestFixtures.appModel(completedSessions: 1)
        defer { harness.cleanup() }
        await harness.model.bootstrap()
        XCTAssertFalse(harness.model.hasAccess(to: .csvExport))
        XCTAssertNil(harness.model.makeCSVExport())
        XCTAssertTrue(harness.model.isPaywallPresented)
        XCTAssertEqual(harness.model.requestedProFeature, .csvExport)
        XCTAssertTrue(harness.model.resumesIntentAfterUnlock)

        harness.purchases.entitlement = .pro
        harness.purchases.outcome = .purchased
        await harness.model.purchaseLifetime()
        XCTAssertFalse(harness.model.isPaywallPresented)
        XCTAssertTrue(harness.model.hasAccess(to: .csvExport))
        XCTAssertNil(harness.model.alertMessage, "History reopens the export; a success alert would compete with it.")
    }

    func testOtherProFeaturePurchaseStillConfirmsWithAnAlert() async throws {
        let harness = try TestFixtures.appModel(completedSessions: 1)
        defer { harness.cleanup() }
        await harness.model.bootstrap()
        harness.model.requestAccess(to: .parkingCosts)
        XCTAssertFalse(harness.model.resumesIntentAfterUnlock)
        harness.purchases.entitlement = .pro
        harness.purchases.outcome = .purchased
        await harness.model.purchaseLifetime()
        XCTAssertEqual(harness.model.alertMessage, "Lifetime Pro is unlocked.")
    }

    func testOfferRequestedInsideTheParkingEditorIsPresentedByTheEditor() async throws {
        let harness = try TestFixtures.appModel()
        defer { harness.cleanup() }
        await harness.model.bootstrap()
        harness.model.parkingEditorDidAppear()
        harness.model.requestAccess(to: .parkingCosts)
        XCTAssertTrue(harness.model.isPaywallPresented)
        XCTAssertEqual(harness.model.paywallHost, .parkingEditor)

        harness.purchases.entitlement = .pro
        harness.purchases.outcome = .purchased
        await harness.model.purchaseLifetime()
        XCTAssertFalse(harness.model.isPaywallPresented)
        XCTAssertTrue(harness.model.hasAccess(to: .parkingCosts), "The editor's cost field unlocks in place.")
        XCTAssertNil(
            harness.model.alertMessage,
            "The tab view's success alert would discard the open editor; the unlocked field confirms the purchase."
        )
        XCTAssertEqual(harness.model.paywallHost, .parkingEditor, "The host only changes when an offer opens.")
        harness.model.parkingEditorDidDisappear()

        harness.model.requestAccess(to: .fullHistory)
        XCTAssertEqual(harness.model.paywallHost, .root, "Offers outside the editor stay on the tab view.")
    }

    func testRestoreFromTheOfferOverTheEditorLeavesTheEditorWithoutAnAlert() async throws {
        let harness = try TestFixtures.appModel()
        defer { harness.cleanup() }
        await harness.model.bootstrap()
        harness.model.parkingEditorDidAppear()
        harness.model.requestAccess(to: .parkingCosts)
        XCTAssertEqual(harness.model.paywallHost, .parkingEditor)

        harness.purchases.entitlement = .pro
        await harness.model.restorePurchases()
        XCTAssertFalse(harness.model.isPaywallPresented)
        XCTAssertTrue(harness.model.hasAccess(to: .parkingCosts))
        XCTAssertNil(harness.model.alertMessage, "A root alert would discard the open editor.")
    }

    func testFreeSaveFromTheEditorDropsTheCostWithoutOpeningTheOffer() async throws {
        let harness = try TestFixtures.appModel(completedSessions: 1)
        defer { harness.cleanup() }
        await harness.model.bootstrap()
        harness.model.parkingEditorDidAppear()
        var draft = await harness.model.newParkingDraft()
        draft.paidAmountMinor = 450
        let saved = await harness.model.saveNew(draft: draft, replacingActive: false)
        XCTAssertTrue(saved)
        XCTAssertFalse(harness.model.isPaywallPresented)
        XCTAssertNil(harness.model.activeSession?.paidAmountMinor, "Cost records are a Pro extra.")
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

    func testParkingIsFreeAndUnlimitedWithoutPro() async throws {
        let harness = try TestFixtures.appModel(completedSessions: 5)
        defer { harness.cleanup() }
        await harness.model.bootstrap()
        XCTAssertEqual(harness.model.entitlement, .free)

        let draft = await harness.model.newParkingDraft()
        let saved = await harness.model.saveNew(draft: draft, replacingActive: false)
        XCTAssertTrue(saved, "Saving a spot never needs a purchase.")
        let first = try XCTUnwrap(harness.model.activeSession)
        let replaced = await harness.model.saveNew(draft: draft, replacingActive: true)
        XCTAssertTrue(replaced, "Parking somewhere else is free too.")
        XCTAssertNotEqual(harness.model.activeSession?.id, first.id)
        XCTAssertFalse(harness.model.isPaywallPresented)

        await harness.model.finishActive()
        XCTAssertEqual(harness.model.completedSessions.count, 7)
        XCTAssertEqual(harness.model.visibleHistory.count, FeatureAccessPolicy.freeHistoryLimit)
        XCTAssertEqual(harness.model.hiddenHistoryCount, 7 - FeatureAccessPolicy.freeHistoryLimit)
        XCTAssertEqual(harness.model.reminderOffsets, ReminderPlanner.freeOffsets)
        XCTAssertFalse(harness.model.hasAccess(to: .customReminders))
    }

    func testCancelledPendingAndUnverifiedPurchaseKeepProExtrasLocked() async throws {
        for outcome in [PurchaseOutcome.cancelled, .pending, .purchased] {
            let harness = try TestFixtures.appModel(completedSessions: 1)
            defer { harness.cleanup() }
            harness.purchases.outcome = outcome
            await harness.model.bootstrap()
            harness.model.requestAccess(to: .fullHistory)
            await harness.model.purchaseLifetime()
            XCTAssertFalse(harness.model.hasAccess(to: .fullHistory))
            XCTAssertTrue(harness.model.isPaywallPresented)
        }
    }

    func testVerifiedPurchaseUnlocksAndRevocationLocksOnlyProExtras() async throws {
        let harness = try TestFixtures.appModel(completedSessions: 5)
        defer { harness.cleanup() }
        await harness.model.bootstrap()
        harness.model.requestAccess(to: .fullHistory)
        harness.purchases.entitlement = .pro
        harness.purchases.outcome = .purchased
        await harness.model.purchaseLifetime()
        XCTAssertTrue(harness.model.hasAccess(to: .fullHistory))
        XCTAssertEqual(harness.model.visibleHistory.count, 5)
        XCTAssertFalse(harness.model.isPaywallPresented)
        let draft = await harness.model.newParkingDraft()
        let saved = await harness.model.saveNew(draft: draft, replacingActive: false)
        XCTAssertTrue(saved)
        let id = harness.model.activeSession?.id

        harness.purchases.entitlement = .free
        await harness.model.restorePurchases()
        XCTAssertFalse(harness.model.hasAccess(to: .fullHistory))
        XCTAssertEqual(harness.model.activeSession?.id, id, "Losing Pro never touches the saved spot.")
        harness.model.openDirections()
        await harness.model.finishActive()
        XCTAssertNil(harness.model.activeSession)
        XCTAssertTrue(harness.model.completedSessions.contains { $0.id == id })
    }

    func testRestoreWithNothingToRestoreSaysSoAndKeepsTheOfferOpen() async throws {
        let harness = try TestFixtures.appModel()
        defer { harness.cleanup() }
        await harness.model.bootstrap()
        harness.model.requestAccess(to: .customReminders)
        await harness.model.restorePurchases()
        XCTAssertEqual(harness.model.alertMessage, "No Lifetime Pro purchase was found for this Apple ID.")
        XCTAssertTrue(harness.model.isPaywallPresented, "Nothing was restored, so the offer stays open")
    }

    func testFailedRestoreReportsTheStoreAndKeepsParking() async throws {
        let harness = try TestFixtures.appModel(completedSessions: 1)
        defer { harness.cleanup() }
        harness.purchases.restoreFails = true
        await harness.model.bootstrap()
        await harness.model.restorePurchases()
        XCTAssertTrue(try XCTUnwrap(harness.model.alertMessage).contains("could not restore Lifetime Pro"))
        let draft = await harness.model.newParkingDraft()
        let saved = await harness.model.saveNew(draft: draft, replacingActive: false)
        XCTAssertTrue(saved)
    }

    func testRestoreFromSettingsConfirmsWithAnAlert() async throws {
        let harness = try TestFixtures.appModel()
        defer { harness.cleanup() }
        await harness.model.bootstrap()
        harness.purchases.entitlement = .pro
        await harness.model.restorePurchases()
        XCTAssertEqual(harness.model.alertMessage, "Lifetime Pro was restored.")
        XCTAssertTrue(harness.model.hasAccess(to: .csvExport))
    }

    func testPendingApprovalDismissesTheOfferAfterVerifiedUpdate() async throws {
        let harness = try TestFixtures.appModel(completedSessions: 1)
        defer { harness.cleanup() }
        harness.purchases.outcome = .pending
        await harness.model.bootstrap()
        harness.model.requestAccess(to: .parkingCosts)
        await harness.model.purchaseLifetime()
        XCTAssertFalse(harness.model.hasAccess(to: .parkingCosts))
        XCTAssertTrue(harness.model.isPaywallPresented)
        await sendEntitlementUpdate(.pro, in: harness)
        XCTAssertTrue(harness.model.hasAccess(to: .parkingCosts))
        XCTAssertFalse(harness.model.isPaywallPresented)
        XCTAssertNil(harness.model.alertMessage)
        harness.model.paywallDidDismiss()
        XCTAssertEqual(harness.model.paywallDismissalCount, 1)
        await sendEntitlementUpdate(.pro, in: harness)
        XCTAssertEqual(harness.model.paywallDismissalCount, 1)
    }

    func testLaterApprovalDoesNotReopenAClosedOffer() async throws {
        let harness = try TestFixtures.appModel(completedSessions: 1)
        defer { harness.cleanup() }
        await harness.model.bootstrap()
        harness.model.requestAccess(to: .customReminders)
        harness.model.isPaywallPresented = false
        harness.model.paywallDidDismiss()
        await sendEntitlementUpdate(.pro, in: harness)
        XCTAssertFalse(harness.model.isPaywallPresented)
        XCTAssertEqual(harness.model.paywallDismissalCount, 1)
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
                return EntitlementState.pro
            }
            XCTFail("A stalled store call must not produce an entitlement")
        } catch {
            XCTAssertEqual(error as? PurchaseServiceError, .storeUnavailable)
        }
        XCTAssertLessThan(started.duration(to: .now), .seconds(3))
    }

    func testPromptStoreResultPassesThrough() async throws {
        let state = try await withStoreDeadline(seconds: 5) { EntitlementState.free }
        XCTAssertEqual(state, .free)
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
