import XCTest
@testable import ParkNudge

final class ReviewPromptPolicyTests: XCTestCase {
    private func context(
        completed: Int = 3,
        lastVersion: String? = nil,
        currentVersion: String = "1.0.0",
        alert: Bool = false,
        paywall: Bool = false,
        busy: Bool = false
    ) -> ReviewPromptContext {
        ReviewPromptContext(
            completedSessionCount: completed,
            lastRequestedVersion: lastVersion,
            currentVersion: currentVersion,
            hasActiveAlert: alert,
            isPaywallPresented: paywall,
            isBusy: busy
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
            "The first completion also raises the paywall; asking there is exactly the pressure to avoid"
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
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(context(completed: 99, paywall: true)))
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(context(completed: 99, busy: true)))
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
