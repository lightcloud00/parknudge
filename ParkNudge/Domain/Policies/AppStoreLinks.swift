import Foundation

/// App Store destinations for ParkNudge.
///
/// The Settings "Rate ParkNudge" row opens `writeReviewURL`. It is a plain
/// link: it never calls StoreKit's `requestReview`, which stays reserved for
/// the earned moments decided by `ReviewPromptPolicy`.
enum AppStoreLinks {
    static let appID = "6803750420"

    static let writeReviewURL = URL(
        string: "https://apps.apple.com/app/id\(appID)?action=write-review"
    )!
}
