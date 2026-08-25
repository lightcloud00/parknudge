import StoreKit
import UIKit

/// Hands the request to StoreKit, and stops there.
///
/// Whether the prompt is shown is Apple's decision, is rate-limited per Apple
/// ID, and is never reported back. A no-op here — no foreground scene, request
/// swallowed — is indistinguishable from a shown prompt, which is exactly why
/// nothing downstream may treat calling this as evidence that a user was asked.
@MainActor
final class StoreKitReviewRequester: ReviewRequesting {
    func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        AppStore.requestReview(in: scene)
    }
}
