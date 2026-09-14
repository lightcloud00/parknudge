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

    private func imageData(color: UIColor) -> Data? {
        UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }.pngData()
    }
}
