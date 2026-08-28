@testable import ParkNudge
import XCTest

final class UITestMeterSeedTests: XCTestCase {
    func testLegacyActiveMeterFlagUsesDefaultOffset() throws {
        XCTAssertEqual(
            try UITestMeterSeed.offset(arguments: ["ParkNudge", "-ui-test-active-meter"]),
            3_600
        )
    }

    func testArbitraryPositiveAndNegativeOffsetsAreAccepted() throws {
        XCTAssertEqual(
            try UITestMeterSeed.offset(arguments: ["-ui-test-meter-offset=600"]),
            600
        )
        XCTAssertEqual(
            try UITestMeterSeed.offset(arguments: ["-ui-test-meter-offset=-720"]),
            -720
        )
    }

    func testMalformedDuplicateAndUnboundedOffsetsFailClosed() {
        XCTAssertThrowsError(
            try UITestMeterSeed.offset(arguments: ["-ui-test-meter-offset=tomorrow"])
        )
        XCTAssertThrowsError(
            try UITestMeterSeed.offset(arguments: [
                "-ui-test-meter-offset=60",
                "-ui-test-meter-offset=120",
            ])
        )
        XCTAssertThrowsError(
            try UITestMeterSeed.offset(arguments: ["-ui-test-meter-offset=999999999"])
        )
    }

    func testNoMeterArgumentDoesNotSeed() throws {
        XCTAssertNil(try UITestMeterSeed.offset(arguments: ["ParkNudge", "-ui-testing"]))
    }
}
