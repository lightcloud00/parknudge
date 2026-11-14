import Foundation
import os
@preconcurrency import SuperwallKit
import UIKit

/// The only place ParkNudge calls SuperwallKit.
///
/// `configureIfEnabled` calls `Superwall.configure` only when
/// `SuperwallActivation` is `.enabled`: a valid `pk_` key was injected and
/// this is not a UI-test launch. Otherwise no SuperwallKit symbol is touched
/// and the native `PaywallView` is presented exactly as before.
///
/// `StoreKitPurchaseService`, through `AppModel`, stays the purchase owner.
/// Superwall renders the paywall and calls back into the same purchase and
/// restore those native buttons use. There is no `identify` call: ParkNudge
/// has no account, and Superwall keeps its own anonymous install alias.
@MainActor
final class SuperwallBridge: RemotePaywallPresenting {
    private static let log = Logger(
        subsystem: "com.gusdigitalsolutions.parknudge",
        category: "SuperwallBridge"
    )

    private(set) var isConfigured = false
    private(set) var activation: SuperwallActivation?
    private var purchaseController: ParkNudgeSuperwallPurchaseController?
    private let requests = SuperwallPaywallRequests()

    var defersNativePaywall: Bool { isConfigured }

    func configureIfEnabled(
        owner: any LifetimePurchaseOwning,
        rawAPIKey: String? = SuperwallConfig.bundledAPIKey(),
        isAutomatedUITest: Bool = ProcessInfo.processInfo.arguments.contains("-ui-testing")
    ) {
        guard activation == nil else { return }
        let resolved = SuperwallActivation.resolve(
            rawAPIKey: rawAPIKey,
            isAutomatedUITest: isAutomatedUITest
        )
        activation = resolved
        guard case .enabled(let apiKey) = resolved else {
            // Dormant reasons do not contain the key.
            Self.log.info("Superwall dormant: \(String(describing: resolved), privacy: .public)")
            return
        }

        let controller = ParkNudgeSuperwallPurchaseController(owner: owner)
        purchaseController = controller
        Superwall.configure(apiKey: apiKey, purchaseController: controller)
        isConfigured = true
        noteEntitlement(owner.entitlement)
    }

    func presentPaywall(
        entryPoint: String,
        fallback: @escaping @MainActor () -> Void,
        onFinish: @escaping @MainActor () -> Void
    ) {
        guard isConfigured else {
            var policy = SuperwallPaywallFallbackPolicy()
            if policy.react(to: .notConfigured).presentsNativePaywall {
                fallback()
            }
            onFinish()
            return
        }

        // Until Superwall holds a config, `register` waits with nothing on
        // screen. The native paywall answers the tap immediately.
        guard Superwall.shared.configurationStatus == .configured else {
            Self.log.info("parknudge_paywall configuration not ready; native paywall shown")
            var policy = SuperwallPaywallFallbackPolicy()
            if policy.react(to: .configurationNotReady).presentsNativePaywall {
                fallback()
            }
            onFinish()
            return
        }

        let request: SuperwallPaywallRequest
        switch requests.begin(fallback: fallback, onFinish: onFinish) {
        case .alreadyInFlight:
            Self.log.info("parknudge_paywall already in flight; ignoring a repeated request")
            return
        case .answeredWithNativePaywall:
            Self.log.info("parknudge_paywall still finishing an earlier registration; native paywall shown")
            return
        case .register(let registered):
            request = registered
        }

        let handler = PaywallPresentationHandler()
        handler.onPresent { @Sendable [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard request.isFinished else {
                    request.handle(.presented)
                    return
                }
                await self.dismissLatePaywall(of: request)
            }
        }
        handler.onDismiss { @Sendable paywallInfo, _ in
            let event = SuperwallResultMapping.dismissalEvent(paywallInfo.closeReason)
            Task { @MainActor in request.handle(event) }
        }
        handler.onSkip { @Sendable reason in
            let description = reason.description
            Task { @MainActor in
                Self.log.info("parknudge_paywall skipped: \(description, privacy: .public)")
                request.handle(.skipped)
            }
        }
        handler.onError { @Sendable error in
            let nsError = error as NSError
            let event = SuperwallPaywallEvent.presentationError(
                domain: nsError.domain,
                code: nsError.code
            )
            let message = error.localizedDescription
            Task { @MainActor in
                Self.log.error("parknudge_paywall failed: \(message, privacy: .public)")
                request.handle(event)
            }
        }

        Superwall.shared.register(
            placement: SuperwallConfig.paywallPlacement,
            params: SuperwallConfig.placementParams(
                entryPoint: entryPoint,
                reduceMotion: UIAccessibility.isReduceMotionEnabled
            ),
            handler: handler
        )
    }

    func noteEntitlement(_ state: EntitlementState) {
        guard isConfigured else { return }
        let status = SuperwallResultMapping.subscriptionStatus(
            SuperwallSubscriptionDecision.forEntitlement(state)
        )
        if Superwall.shared.subscriptionStatus != status {
            Superwall.shared.subscriptionStatus = status
        }
    }

    private func dismissLatePaywall(of request: SuperwallPaywallRequest) async {
        guard requests.shouldDismissLatePaywall(of: request) else { return }
        Self.log.info("parknudge_paywall presented after its deadline; dismissing it")
        await Superwall.shared.dismiss()
    }
}

/// SuperwallKit purchase controller. It sells only Lifetime Pro, and only by
/// calling the purchase owner. A different product id never reaches StoreKit.
@MainActor
final class ParkNudgeSuperwallPurchaseController: PurchaseController {
    private weak var owner: (any LifetimePurchaseOwning)?

    init(owner: any LifetimePurchaseOwning) {
        self.owner = owner
    }

    func purchase(product: StoreProduct) async -> PurchaseResult {
        let productID = product.productIdentifier
        guard SuperwallConfig.sells(productID) else {
            return .failed(RemotePaywallError(
                message: "This paywall offered a product ParkNudge does not sell. Nothing was charged."
            ))
        }
        guard let owner else {
            return .failed(RemotePaywallError(
                message: PurchaseServiceError.storeUnavailable.localizedDescription
                    ?? "The App Store could not be reached. Your saved parking details remain available."
            ))
        }
        return SuperwallResultMapping.purchaseResult(await owner.purchaseForRemotePaywall())
    }

    func restorePurchases() async -> RestorationResult {
        guard let owner else {
            return .failed(RemotePaywallError(
                message: "The App Store could not restore Lifetime Pro. Try Restore Purchases again when the store is available. Your saved spot remains available."
            ))
        }
        return SuperwallResultMapping.restorationResult(await owner.restoreForRemotePaywall())
    }
}

/// SDK-free decision to the SuperwallKit value the paywall actually receives.
enum SuperwallResultMapping {
    static func subscriptionStatus(_ decision: SuperwallSubscriptionDecision) -> SubscriptionStatus {
        switch decision {
        case .unknown: .unknown
        case .inactive: .inactive
        case .active: .active([Entitlement(id: SuperwallConfig.proEntitlementID)])
        }
    }

    static func purchaseResult(_ report: RemotePurchaseReport) -> PurchaseResult {
        switch report {
        case .purchased: .purchased
        case .cancelled: .cancelled
        case .pending: .pending
        case .failed(let message): .failed(RemotePaywallError(message: message))
        }
    }

    static func restorationResult(_ report: RemoteRestoreReport) -> RestorationResult {
        switch report {
        case .restored: .restored
        case .failed(let message): .failed(RemotePaywallError(message: message))
        }
    }

    static func dismissalEvent(_ closeReason: PaywallCloseReason) -> SuperwallPaywallEvent {
        switch closeReason {
        case .webViewFailedToLoad: .dismissedAfterLoadFailure
        case .forNextPaywall: .dismissedForNextPaywall
        case .systemLogic, .manualClose, .none: .dismissed
        }
    }
}
