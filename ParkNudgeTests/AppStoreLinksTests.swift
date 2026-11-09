import XCTest
@testable import ParkNudge

final class AppStoreLinksTests: XCTestCase {
    func testWriteReviewURLIsExactlyTheWriteReviewPageForParkNudge() {
        XCTAssertEqual(AppStoreLinks.appID, "6803750420")
        XCTAssertEqual(
            AppStoreLinks.writeReviewURL.absoluteString,
            "https://apps.apple.com/app/id6803750420?action=write-review"
        )
    }
}
