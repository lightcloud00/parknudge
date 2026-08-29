import StoreKit
import UIKit

/// Hands the request to StoreKit, and stops there.
///
/// Whether the prompt is shown is Apple's decision, is rate-limited per Apple
/// ID, and is never reported back. The return value reports only whether this
/// adapter found a valid scene and invoked StoreKit.
@MainActor
final class StoreKitReviewRequester: ReviewRequesting {
    @discardableResult
    func requestReview() -> Bool {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: {
                $0.activationState == .foregroundActive &&
                    $0.windows.contains(where: \.isKeyWindow)
            })
        else { return false }

        AppStore.requestReview(in: scene)
        return true
    }
}
