import XCTest
@testable import ParkNudge

final class ReviewPromptPolicyTests: XCTestCase {
    private func context(
        completed: Int = 3,
        lastVersion: String? = nil,
        lastDate: Date? = nil,
        currentVersion: String = "1.0.0",
        now: Date = Date(timeIntervalSince1970: 20_000_000),
        alert: Bool = false,
        confirmation: Bool = false,
        paywall: Bool = false,
        purchase: Bool = false,
        busy: Bool = false,
        onboarding: Bool = false,
        launch: Bool = false
    ) -> ReviewPromptContext {
        ReviewPromptContext(
            completedSessionCount: completed,
            lastRequestedVersion: lastVersion,
            lastRequestedDate: lastDate,
            currentVersion: currentVersion,
            now: now,
            hasActiveAlert: alert,
            hasActiveConfirmation: confirmation,
            isPaywallPresented: paywall,
            isPurchasePresented: purchase,
            isBusy: busy,
            isOnboardingPresented: onboarding,
            isLaunchInProgress: launch
        )
    }

    // MARK: - The eligible case

    func testAsksOnTheThirdCompletedSession() {
        XCTAssertTrue(ReviewPromptPolicy.shouldRequest(context(completed: 3)))
    }

    func testKeepsAskingOnLaterSessionsWhileTheVersionIsNew() {
        XCTAssertTrue(ReviewPromptPolicy.shouldRequest(context(completed: 12)))
    }

    // MARK: - Too early

    func testNeverAsksOnTheFirstCompletedSession() {
        XCTAssertFalse(
            ReviewPromptPolicy.shouldRequest(context(completed: 1)),
            "One completion is too early for a rating request"
        )
    }

    func testNeverAsksOnTheSecondCompletedSession() {
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(context(completed: 2)))
    }

    func testNeverAsksWithNoCompletedSessions() {
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(context(completed: 0)))
    }

    // MARK: - Already attempted for this version

    func testDoesNotAskTwiceForTheSameVersion() {
        XCTAssertFalse(
            ReviewPromptPolicy.shouldRequest(context(lastVersion: "1.0.0", currentVersion: "1.0.0"))
        )
    }

    func testAsksAgainAfterAVersionBump() {
        XCTAssertTrue(
            ReviewPromptPolicy.shouldRequest(context(lastVersion: "1.0.0", currentVersion: "1.1.0"))
        )
    }

    func testCooldownStillAppliesAfterAVersionBump() {
        let now = Date(timeIntervalSince1970: 20_000_000)
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(context(
            lastVersion: "1.0.0",
            lastDate: now.addingTimeInterval(-ReviewPromptPolicy.cooldown + 1),
            currentVersion: "1.1.0",
            now: now
        )))
        XCTAssertTrue(ReviewPromptPolicy.shouldRequest(context(
            lastVersion: "1.0.0",
            lastDate: now.addingTimeInterval(-ReviewPromptPolicy.cooldown),
            currentVersion: "1.1.0",
            now: now
        )))
    }

    func testMissingVersionSuppressesRequest() {
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(context(currentVersion: "")))
    }

    // MARK: - Pressure and failure states

    func testDoesNotAskWhileAnErrorIsOnScreen() {
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(context(alert: true)))
    }

    func testDoesNotAskWhileThePaywallIsPresented() {
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(context(paywall: true)))
    }

    func testDoesNotAskWhileWorkIsInFlight() {
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(context(busy: true)))
    }

    /// Each blocker stands on its own — none of them may be rescued by the
    /// session count being comfortably high.
    func testEachBlockerHoldsIndependentlyOfSessionCount() {
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(context(completed: 99, alert: true)))
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(context(completed: 99, confirmation: true)))
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(context(completed: 99, paywall: true)))
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(context(completed: 99, purchase: true)))
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(context(completed: 99, busy: true)))
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(context(completed: 99, onboarding: true)))
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(context(completed: 99, launch: true)))
        XCTAssertFalse(
            ReviewPromptPolicy.shouldRequest(
                context(completed: 99, lastVersion: "2.0", currentVersion: "2.0")
            )
        )
    }

    func testThresholdIsTheDocumentedThird() {
        XCTAssertEqual(ReviewPromptPolicy.minimumCompletedSessions, 3)
    }
}
