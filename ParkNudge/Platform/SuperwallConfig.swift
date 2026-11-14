import Foundation

/// Identifiers and public-key validation for the Superwall paywall.
///
/// SuperwallKit only presents. `StoreKitPurchaseService` stays the purchase
/// owner, and a verified StoreKit transaction is still the only thing that
/// unlocks Lifetime Pro. This file does not import SuperwallKit, so the
/// decisions below are unit-testable without the SDK.
enum SuperwallConfig {
    /// Info.plist key filled from the `SUPERWALL_PUBLIC_API_KEY` build setting.
    /// The committed value is empty. A Release archive can override it; the
    /// repository never stores a key.
    static let infoPlistKey = "SUPERWALL_PUBLIC_API_KEY"

    /// The one placement that stands in for the native Lifetime Pro paywall.
    static let paywallPlacement = "parknudge_paywall"

    /// Superwall entitlement id that mirrors verified Lifetime Pro. It does not
    /// grant Pro; `subscriptionStatus` is a display hint for the paywall.
    static let proEntitlementID = "pro"

    /// Superwall documents `pk_` as the public client-key prefix. A secret
    /// key, another provider's key, or an unexpanded `$(SUPERWALL_PUBLIC_API_KEY)`
    /// keeps the SDK dormant.
    static let publicKeyPrefix = "pk_"
    static let minimumKeyBodyLength = 16

    /// How long one registration may take to put a paywall on screen before
    /// the native paywall opens instead. A paywall that appears after this is
    /// dismissed so it cannot sit on top of the native one.
    static let presentationDeadline: Duration = .milliseconds(2500)

    static var lifetimeProductID: String { StoreKitPurchaseService.productIdentifier }

    /// The paywall may sell only Lifetime Pro. Any other product id is refused
    /// before StoreKit is asked.
    static func sells(_ productID: String) -> Bool {
        productID == lifetimeProductID
    }

    /// The trimmed key when it is `pk_` plus at least 16 characters from
    /// `[A-Za-z0-9_-]`. Anything else is nil.
    static func validPublicAPIKey(_ candidate: String?) -> String? {
        guard let key = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
              key.hasPrefix(publicKeyPrefix) else {
            return nil
        }
        let body = key.dropFirst(publicKeyPrefix.count)
        guard body.count >= minimumKeyBodyLength,
              body.unicodeScalars.allSatisfy({ allowedKeyScalars.contains($0) }) else {
            return nil
        }
        return key
    }

    /// The value Info.plist resolved at build time, still unvalidated.
    static func bundledAPIKey(bundle: Bundle = .main) -> String? {
        bundle.object(forInfoDictionaryKey: infoPlistKey) as? String
    }

    enum ParamKey {
        static let entryPoint = "entryPoint"
        static let reduceMotion = "reduceMotion"
    }

    /// Params for `parknudge_paywall`. Keys beginning with `$` are reserved by
    /// Superwall and dropped, so neither of these may. No product id is sent.
    static func placementParams(entryPoint: String, reduceMotion: Bool) -> [String: Any] {
        [
            ParamKey.entryPoint: entryPoint,
            ParamKey.reduceMotion: reduceMotion,
        ]
    }

    private static let allowedKeyScalars: CharacterSet = {
        var set = CharacterSet()
        set.insert(charactersIn: "abcdefghijklmnopqrstuvwxyz")
        set.insert(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        set.insert(charactersIn: "0123456789_-")
        return set
    }()
}

/// Where the customer asked to see Lifetime Pro.
enum PaywallEntryPoint: String, Equatable, Sendable {
    case settings
    case onboarding
    case fullHistory
    case customReminders
    case parkingCosts
    case csvExport

    init(_ feature: ProFeature) {
        switch feature {
        case .fullHistory: self = .fullHistory
        case .customReminders: self = .customReminders
        case .parkingCosts: self = .parkingCosts
        case .csvExport: self = .csvExport
        }
    }
}

/// Whether this launch may call `Superwall.configure`.
enum SuperwallActivation: Equatable, Sendable {
    case enabled(apiKey: String)
    case dormant(DormantReason)

    enum DormantReason: Equatable, Sendable, CustomStringConvertible {
        /// UI tests drive the native paywall. The SDK stays untouched even if
        /// a key was injected into the test host.
        case automatedUITest
        /// The build setting is unset or empty.
        case missingAPIKey
        /// A value is present but is not a Superwall public key.
        case invalidAPIKey

        var description: String {
            switch self {
            case .automatedUITest: "automated UI test"
            case .missingAPIKey: "SUPERWALL_PUBLIC_API_KEY is empty"
            case .invalidAPIKey: "SUPERWALL_PUBLIC_API_KEY is not a public pk_ key"
            }
        }
    }

    /// A UI-test launch wins before the key is read, so the key is never logged.
    static func resolve(rawAPIKey: String?, isAutomatedUITest: Bool) -> SuperwallActivation {
        guard !isAutomatedUITest else { return .dormant(.automatedUITest) }
        let trimmed = rawAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return .dormant(.missingAPIKey) }
        guard let apiKey = SuperwallConfig.validPublicAPIKey(trimmed) else {
            return .dormant(.invalidAPIKey)
        }
        return .enabled(apiKey: apiKey)
    }
}

/// SDK-free mirror of Superwall's subscription status.
///
/// `.loading` and `.unavailable` stay `.unknown`. Telling Superwall the
/// customer is free before the App Store answers would let a paywall sell
/// Lifetime Pro to someone whose entitlement is still unresolved (#79).
enum SuperwallSubscriptionDecision: Equatable, Sendable {
    case unknown
    case inactive
    case active

    static func forEntitlement(_ state: EntitlementState) -> SuperwallSubscriptionDecision {
        switch state {
        case .loading, .unavailable: .unknown
        case .free: .inactive
        case .pro: .active
        }
    }
}

/// What one StoreKit purchase looked like to the remote paywall.
enum RemotePurchaseReport: Equatable, Sendable {
    case purchased
    case cancelled
    case pending
    case failed(String)
}

/// What one StoreKit restore looked like to the remote paywall.
///
/// `.restored` means the App Store call finished and Lifetime Pro is verified.
/// A restore that finds nothing is `.failed`, because Superwall treats
/// `.restored` as success and then alerts if subscription status is not active.
enum RemoteRestoreReport: Equatable, Sendable {
    case restored
    case failed(String)
}

struct RemotePaywallError: LocalizedError, Equatable, Sendable {
    var message: String
    var errorDescription: String? { message }
}

/// The purchase surface Superwall calls. `AppModel` implements it by running
/// the same purchase and restore the native paywall buttons use.
@MainActor
protocol LifetimePurchaseOwning: AnyObject {
    var entitlement: EntitlementState { get }
    func purchaseForRemotePaywall() async -> RemotePurchaseReport
    func restoreForRemotePaywall() async -> RemoteRestoreReport
}

/// What shows Lifetime Pro. `SuperwallBridge` conforms. `DormantRemotePaywall`
/// presents the native paywall immediately, which is today's behavior.
@MainActor
protocol RemotePaywallPresenting: AnyObject {
    /// When true, the native paywall waits until `fallback` runs. When false,
    /// `presentPaywall` calls `fallback` before it returns.
    var defersNativePaywall: Bool { get }
    func presentPaywall(
        entryPoint: String,
        fallback: @escaping @MainActor () -> Void,
        onFinish: @escaping @MainActor () -> Void
    )
    func noteEntitlement(_ state: EntitlementState)
}

extension RemotePaywallPresenting {
    func noteEntitlement(_ state: EntitlementState) {}
}

@MainActor
final class DormantRemotePaywall: RemotePaywallPresenting {
    var defersNativePaywall: Bool { false }

    func presentPaywall(
        entryPoint: String,
        fallback: @escaping @MainActor () -> Void,
        onFinish: @escaping @MainActor () -> Void
    ) {
        fallback()
        onFinish()
    }
}

/// Lifecycle signals translated from SuperwallKit's presentation handler.
enum SuperwallPaywallEvent: Equatable, Sendable {
    /// Superwall is dormant; nothing was registered.
    case notConfigured
    /// `configurationStatus` is not `.configured`, so `register` would wait
    /// with nothing on screen.
    case configurationNotReady
    /// Holdout, no audience match, or the placement is not on a campaign.
    case skipped
    /// Presentation failed.
    case failed
    /// `SWKPresentationError` 102: a Superwall paywall is already on screen.
    case alreadyPresented
    /// Nothing was on screen when the presentation deadline ended.
    case timedOut
    case presented
    /// The paywall closed for good: purchase, restore, close, or swipe.
    case dismissed
    /// Superwall closed this paywall only to show the next one.
    case dismissedForNextPaywall
    /// The web view failed to load and Superwall closed the paywall.
    case dismissedAfterLoadFailure

    static let presentationErrorDomain = "SWKPresentationError"
    /// "Paywall Already Presented" in SuperwallKit 4.x.
    static let paywallAlreadyPresentedCode = 102

    static func presentationError(domain: String, code: Int) -> SuperwallPaywallEvent {
        domain == presentationErrorDomain && code == paywallAlreadyPresentedCode
            ? .alreadyPresented
            : .failed
    }

    /// The Superwall registration is still open after these, so a later callback
    /// can still arrive. A timeout in particular has already opened the native
    /// paywall and must not be followed by a second `register`.
    var endsSuperwallRegistration: Bool {
        switch self {
        case .presented, .dismissedForNextPaywall, .timedOut, .notConfigured, .configurationNotReady:
            false
        case .skipped, .failed, .alreadyPresented, .dismissed, .dismissedAfterLoadFailure:
            true
        }
    }
}

/// What one event does to its registration.
struct SuperwallPaywallReaction: Equatable, Sendable {
    var presentsNativePaywall = false
    var finishesRequest = false

    static let noEffect = SuperwallPaywallReaction()
}

/// Decides when the native paywall replaces Superwall for one registration.
///
/// Skip (no campaign, holdout, or no audience), a presentation error, a
/// missing configuration, or the deadline before any paywall loaded: show the
/// native paywall. A web view that fails after the paywall was shown does too.
/// A paywall the customer closed, a purchase, a restore, and error 102 do not.
/// The native paywall is shown at most once.
struct SuperwallPaywallFallbackPolicy: Equatable, Sendable {
    private(set) var isRemotePaywallOnScreen = false
    private(set) var didCloseRemotePaywall = false
    private(set) var didPresentNativePaywall = false
    private(set) var isFinished = false

    mutating func react(to event: SuperwallPaywallEvent) -> SuperwallPaywallReaction {
        guard !isFinished else { return .noEffect }
        switch event {
        case .presented:
            isRemotePaywallOnScreen = true
            return .noEffect
        case .dismissed:
            isRemotePaywallOnScreen = false
            return finish()
        case .dismissedForNextPaywall:
            isRemotePaywallOnScreen = false
            didCloseRemotePaywall = true
            return .noEffect
        case .dismissedAfterLoadFailure:
            isRemotePaywallOnScreen = false
            if didCloseRemotePaywall { return finish() }
            return finish(presentingNative: true)
        case .timedOut:
            if isRemotePaywallOnScreen { return .noEffect }
            // A follow-up paywall that never appeared after a decline ends the
            // registration. The customer already closed a paywall that loaded.
            if didCloseRemotePaywall { return finish() }
            return finish(presentingNative: true)
        case .notConfigured, .configurationNotReady, .skipped, .failed, .alreadyPresented:
            if isRemotePaywallOnScreen { return .noEffect }
            if didCloseRemotePaywall { return finish() }
            // 102 means a paywall is already up; the native one would stack on it.
            return finish(presentingNative: event != .alreadyPresented)
        }
    }

    private mutating func finish(presentingNative: Bool = false) -> SuperwallPaywallReaction {
        isFinished = true
        let presentsNative = presentingNative && !didPresentNativePaywall
        if presentsNative { didPresentNativePaywall = true }
        return SuperwallPaywallReaction(
            presentsNativePaywall: presentsNative,
            finishesRequest: true
        )
    }
}

/// One `parknudge_paywall` registration.
@MainActor
final class SuperwallPaywallRequest {
    typealias Sleep = @Sendable (Duration) async throws -> Void

    private var policy = SuperwallPaywallFallbackPolicy()
    private let fallback: @MainActor () -> Void
    private let onFinish: @MainActor (SuperwallPaywallRequest) -> Void
    private let onEvent: @MainActor (SuperwallPaywallEvent, SuperwallPaywallRequest) -> Void
    private var deadline: (duration: Duration, sleep: Sleep)?
    private(set) var deadlineTask: Task<Void, Never>?
    private(set) var isAwaitingSuperwall = false

    init(
        fallback: @escaping @MainActor () -> Void,
        onFinish: @escaping @MainActor (SuperwallPaywallRequest) -> Void,
        onEvent: @escaping @MainActor (SuperwallPaywallEvent, SuperwallPaywallRequest) -> Void = { _, _ in }
    ) {
        self.fallback = fallback
        self.onFinish = onFinish
        self.onEvent = onEvent
    }

    var isFinished: Bool { policy.isFinished }

    func armDeadline(_ duration: Duration, sleep: @escaping Sleep = { try await Task.sleep(for: $0) }) {
        isAwaitingSuperwall = true
        deadline = (duration, sleep)
        scheduleDeadline()
    }

    private func scheduleDeadline() {
        deadlineTask?.cancel()
        guard let deadline, !policy.isFinished else {
            deadlineTask = nil
            return
        }
        deadlineTask = Task { @MainActor [weak self] in
            do {
                try await deadline.sleep(deadline.duration)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.handle(.timedOut)
        }
    }

    func handle(_ event: SuperwallPaywallEvent) {
        if event.endsSuperwallRegistration {
            isAwaitingSuperwall = false
        }
        onEvent(event, self)
        let reaction = policy.react(to: event)
        if reaction.finishesRequest || event == .presented {
            deadlineTask?.cancel()
            deadlineTask = nil
        } else if event == .dismissedForNextPaywall {
            scheduleDeadline()
        }
        if reaction.presentsNativePaywall {
            fallback()
        }
        if reaction.finishesRequest {
            onFinish(self)
        }
    }
}

enum SuperwallRegistrationStart {
    /// A paywall is loading or on screen. The caller must not register or
    /// present the native paywall, or the two would stack.
    case alreadyInFlight
    /// An earlier registration already fell back and Superwall may still
    /// answer it. This tap opens the native paywall and does not register.
    case answeredWithNativePaywall
    case register(SuperwallPaywallRequest)
}

/// At most one `parknudge_paywall` registration at a time.
///
/// A second `register` while the first paywall is loading or on screen fails
/// with error 102, and a fresh policy would stack the native paywall on top.
/// That tap is ignored and does not call `fallback` or `onFinish`.
///
/// A registration that hit its deadline stays "late" until Superwall finishes
/// it. Further taps use the native paywall and do not `register` again.
@MainActor
final class SuperwallPaywallRequests {
    private(set) var active: SuperwallPaywallRequest?
    private(set) var lateRegistration: SuperwallPaywallRequest?

    var isRequestInFlight: Bool { active != nil }

    func begin(
        fallback: @escaping @MainActor () -> Void,
        onFinish: @escaping @MainActor () -> Void,
        deadline: Duration = SuperwallConfig.presentationDeadline,
        sleep: @escaping SuperwallPaywallRequest.Sleep = { try await Task.sleep(for: $0) }
    ) -> SuperwallRegistrationStart {
        guard active == nil else { return .alreadyInFlight }
        if lateRegistration != nil {
            fallback()
            onFinish()
            return .answeredWithNativePaywall
        }
        let finishRegistration = onFinish
        let request = SuperwallPaywallRequest(
            fallback: fallback,
            onFinish: { [weak self] finished in
                if let self, self.active === finished {
                    self.active = nil
                    if finished.isAwaitingSuperwall {
                        self.lateRegistration = finished
                    }
                }
                finishRegistration()
            },
            onEvent: { [weak self] event, changed in
                guard event.endsSuperwallRegistration, self?.lateRegistration === changed else { return }
                self?.lateRegistration = nil
            }
        )
        active = request
        request.armDeadline(deadline, sleep: sleep)
        return .register(request)
    }

    /// A paywall that presents after its registration already ended is closed,
    /// unless a newer registration now owns the screen.
    func shouldDismissLatePaywall(of request: SuperwallPaywallRequest) -> Bool {
        request.isFinished && active == nil
    }
}
