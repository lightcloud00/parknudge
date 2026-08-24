import SwiftUI
import XCTest
@testable import ParkNudge

final class MeterStateTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - State boundaries

    func testWellAheadOfExpiryIsRunning() {
        let state = MeterState.at(now, expiry: now.addingTimeInterval(3_600))
        XCTAssertEqual(state, .running(remaining: 3_600))
    }

    func testOneSecondOutsideThresholdIsStillRunning() {
        let expiry = now.addingTimeInterval(MeterState.warningThreshold + 1)
        guard case .running = MeterState.at(now, expiry: expiry) else {
            return XCTFail("Expected running just outside the warning window")
        }
    }

    func testExactlyAtThresholdIsExpiringSoon() {
        let expiry = now.addingTimeInterval(MeterState.warningThreshold)
        XCTAssertEqual(
            MeterState.at(now, expiry: expiry),
            .expiringSoon(remaining: MeterState.warningThreshold)
        )
    }

    func testOneSecondBeforeExpiryIsExpiringSoon() {
        guard case .expiringSoon = MeterState.at(now, expiry: now.addingTimeInterval(1)) else {
            return XCTFail("Expected expiringSoon one second out")
        }
    }

    /// The moment of expiry counts as expired, not as a zero-second warning.
    func testExactExpiryIsExpired() {
        XCTAssertEqual(MeterState.at(now, expiry: now), .expired(since: 0))
        XCTAssertTrue(MeterState.at(now, expiry: now).isExpired)
    }

    func testPastExpiryReportsHowLongAgo() {
        let expiry = now.addingTimeInterval(-758)
        XCTAssertEqual(MeterState.at(now, expiry: expiry), .expired(since: 758))
    }

    // MARK: - Progress

    func testProgressIsFractionOfTheParkedWindow() {
        let start = now.addingTimeInterval(-1_800)
        let expiry = now.addingTimeInterval(1_800)
        XCTAssertEqual(MeterState.progress(start: start, expiry: expiry, now: now), 0.5, accuracy: 0.0001)
    }

    func testProgressClampsPastExpiry() {
        let start = now.addingTimeInterval(-3_600)
        let expiry = now.addingTimeInterval(-600)
        XCTAssertEqual(MeterState.progress(start: start, expiry: expiry, now: now), 1)
    }

    func testProgressClampsBeforeStart() {
        let start = now.addingTimeInterval(600)
        let expiry = now.addingTimeInterval(3_600)
        XCTAssertEqual(MeterState.progress(start: start, expiry: expiry, now: now), 0)
    }

    /// An expiry saved at or before the session start would otherwise divide by
    /// a non-positive window.
    func testNonPositiveWindowIsFullyElapsed() {
        XCTAssertEqual(MeterState.progress(start: now, expiry: now, now: now), 1)
        XCTAssertEqual(
            MeterState.progress(start: now, expiry: now.addingTimeInterval(-60), now: now),
            1
        )
    }

    // MARK: - Copy

    func testExpiredTitleNamesTheGapInWholeUnits() {
        XCTAssertEqual(MeterState.expired(since: 758).title, "Meter expired 12 min ago")
        XCTAssertEqual(MeterState.expired(since: 7_200).title, "Meter expired 2 hr ago")
        XCTAssertEqual(MeterState.expired(since: 3_900).title, "Meter expired 1 hr 5 min ago")
    }

    /// "expired 0 min ago" reads as broken, so the phrase floors at one minute.
    func testFreshlyExpiredRoundsUpToOneMinute() {
        XCTAssertEqual(MeterState.expired(since: 4).title, "Meter expired 1 min ago")
    }

    func testRunningAndExpiringTitlesAreDistinct() {
        XCTAssertEqual(MeterState.running(remaining: 3_600).title, "Meter time remaining")
        XCTAssertEqual(MeterState.expiringSoon(remaining: 600).title, "Meter expires soon")
    }

    /// After expiry the digits count up, so a returning driver sees the overrun
    /// growing rather than a frozen zero.
    func testExpiredDigitsCountUp() {
        XCTAssertEqual(MeterState.expired(since: 758).digits, "+12:38")
        XCTAssertEqual(MeterState.running(remaining: 6_432).digits, "1:47:12")
        XCTAssertEqual(MeterState.expiringSoon(remaining: 664).digits, "11:04")
    }

    func testEachStateCarriesItsOwnSymbolAndWeight() {
        let symbols = Set([
            MeterState.running(remaining: 1).symbol,
            MeterState.expiringSoon(remaining: 1).symbol,
            MeterState.expired(since: 1).symbol,
        ])
        XCTAssertEqual(symbols.count, 3, "States must stay distinguishable without colour")
        XCTAssertEqual(MeterState.running(remaining: 1).digitWeight, .semibold)
        XCTAssertEqual(MeterState.expiringSoon(remaining: 1).digitWeight, .bold)
        XCTAssertEqual(MeterState.expired(since: 1).digitWeight, .bold)
    }

    func testAccessibilityDescriptionSpellsOutTheDuration() {
        let expiry = now.addingTimeInterval(6_432)
        let description = MeterState.at(now, expiry: expiry).accessibilityDescription(expiry: expiry)
        XCTAssertTrue(
            description.contains("1 hour 47 minutes left"),
            "VoiceOver should not be handed a bare 1:47:12 — got \(description)"
        )
        XCTAssertTrue(description.hasPrefix("Meter time remaining"))
    }

    func testAccessibilityDescriptionForExpiredUsesThePastTense() {
        let expiry = now.addingTimeInterval(-758)
        let description = MeterState.at(now, expiry: expiry).accessibilityDescription(expiry: expiry)
        XCTAssertTrue(description.hasPrefix("Meter expired 12 min ago"))
    }
}
