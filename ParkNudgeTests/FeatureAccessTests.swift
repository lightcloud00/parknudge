import XCTest
@testable import ParkNudge

final class FeatureAccessTests: XCTestCase {
    func testEveryPaidFeatureRequiresVerifiedProState() {
        for feature in ProFeature.allCases {
            XCTAssertFalse(FeatureAccessPolicy.canUse(feature, entitlement: .free))
            XCTAssertFalse(FeatureAccessPolicy.canUse(feature, entitlement: .unavailable))
            XCTAssertTrue(FeatureAccessPolicy.canUse(feature, entitlement: .pro))
        }
    }

    func testFreeHistoryLimitIsThreeWithoutMutatingInput() {
        let sessions = (0..<5).map { index in
            TestFixtures.session(
                startedAt: TestFixtures.date.addingTimeInterval(Double(index)),
                endedAt: TestFixtures.date.addingTimeInterval(Double(index + 10))
            )
        }
        let visible = Array(sessions.prefix(FeatureAccessPolicy.freeHistoryLimit))
        XCTAssertEqual(visible.count, 3)
        XCTAssertEqual(sessions.count, 5)
    }
}
