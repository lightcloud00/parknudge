import XCTest
@testable import ParkNudge

final class SuperwallConfigTests: XCTestCase {
    /// Built in the test so the source tree never contains a `pk_` value.
    private var validKey: String { "pk_" + String(repeating: "a", count: 16) }

    func testValidPublicKeyAcceptsOnlyALongPublicKey() {
        XCTAssertEqual(SuperwallConfig.validPublicAPIKey(" \(validKey) "), validKey)
        XCTAssertEqual(SuperwallConfig.validPublicAPIKey(validKey + "_9"), validKey + "_9")
        XCTAssertNil(SuperwallConfig.validPublicAPIKey(nil))
        XCTAssertNil(SuperwallConfig.validPublicAPIKey(""))
        XCTAssertNil(SuperwallConfig.validPublicAPIKey("   "))
        XCTAssertNil(SuperwallConfig.validPublicAPIKey("pk_" + String(repeating: "a", count: 5)))
        XCTAssertNil(SuperwallConfig.validPublicAPIKey("sk_" + String(repeating: "a", count: 16)))
        XCTAssertNil(SuperwallConfig.validPublicAPIKey("PK_" + String(repeating: "a", count: 16)))
        XCTAssertNil(SuperwallConfig.validPublicAPIKey("pk_" + String(repeating: "a", count: 10) + " " + String(repeating: "b", count: 6)))
        XCTAssertNil(SuperwallConfig.validPublicAPIKey("$(SUPERWALL_PUBLIC_API_KEY)"))
    }

    func testActivationStaysDormantWithoutAPublicKey() {
        XCTAssertEqual(
            SuperwallActivation.resolve(rawAPIKey: nil, isAutomatedUITest: false),
            .dormant(.missingAPIKey)
        )
        XCTAssertEqual(
            SuperwallActivation.resolve(rawAPIKey: "sk_" + String(repeating: "a", count: 16), isAutomatedUITest: false),
            .dormant(.invalidAPIKey)
        )
        XCTAssertEqual(
            SuperwallActivation.resolve(rawAPIKey: validKey, isAutomatedUITest: true),
            .dormant(.automatedUITest)
        )
        XCTAssertEqual(
            SuperwallActivation.resolve(rawAPIKey: " \(validKey) ", isAutomatedUITest: false),
            .enabled(apiKey: validKey)
        )
    }

    func testOnlyTheLifetimeProductIsSold() {
        XCTAssertTrue(SuperwallConfig.sells(StoreKitPurchaseService.productIdentifier))
        XCTAssertEqual(
            StoreKitPurchaseService.productIdentifier,
            "com.gusdigitalsolutions.parknudge.pro.lifetime"
        )
        XCTAssertFalse(SuperwallConfig.sells("com.gusdigitalsolutions.parknudge.pro.monthly"))
        XCTAssertFalse(SuperwallConfig.sells(""))
    }

    func testUnresolvedEntitlementStaysUnknownToSuperwall() {
        XCTAssertEqual(SuperwallSubscriptionDecision.forEntitlement(.loading), .unknown)
        XCTAssertEqual(SuperwallSubscriptionDecision.forEntitlement(.unavailable), .unknown)
        XCTAssertEqual(SuperwallSubscriptionDecision.forEntitlement(.free), .inactive)
        XCTAssertEqual(SuperwallSubscriptionDecision.forEntitlement(.pro), .active)
    }

    func testPlacementParamsDoNotNameTheProduct() {
        let params = SuperwallConfig.placementParams(entryPoint: "settings", reduceMotion: true)
        XCTAssertEqual(params["entryPoint"] as? String, "settings")
        XCTAssertEqual(params["reduceMotion"] as? Bool, true)
        XCTAssertEqual(params.count, 2)
        XCTAssertTrue(params.keys.allSatisfy { !$0.hasPrefix("$") })
    }

    func testEntryPointFollowsTheLockedFeature() {
        XCTAssertEqual(PaywallEntryPoint(.csvExport), .csvExport)
        XCTAssertEqual(PaywallEntryPoint(.fullHistory).rawValue, "fullHistory")
        XCTAssertEqual(PaywallEntryPoint.settings.rawValue, "settings")
        XCTAssertEqual(PaywallEntryPoint.onboarding.rawValue, "onboarding")
    }

    func testPresentationError102DoesNotMeanThePaywallFailed() {
        XCTAssertEqual(
            SuperwallPaywallEvent.presentationError(domain: "SWKPresentationError", code: 102),
            .alreadyPresented
        )
        XCTAssertEqual(
            SuperwallPaywallEvent.presentationError(domain: "SWKPresentationError", code: 106),
            .failed
        )
        XCTAssertEqual(
            SuperwallPaywallEvent.presentationError(domain: "Other", code: 102),
            .failed
        )
    }

    func testMissingCampaignHoldoutAndFailureShowTheNativePaywall() {
        for event in [
            SuperwallPaywallEvent.notConfigured,
            .configurationNotReady,
            .skipped,
            .failed,
            .timedOut,
        ] {
            var policy = SuperwallPaywallFallbackPolicy()
            let reaction = policy.react(to: event)
            XCTAssertTrue(reaction.presentsNativePaywall, "\(event) should show the native paywall")
            XCTAssertTrue(reaction.finishesRequest)
            XCTAssertFalse(policy.react(to: event).presentsNativePaywall, "the native paywall is shown once")
        }
    }

    func testPaywallAlreadyPresentedDoesNotStackTheNativePaywall() {
        var policy = SuperwallPaywallFallbackPolicy()
        let reaction = policy.react(to: .alreadyPresented)
        XCTAssertFalse(reaction.presentsNativePaywall)
        XCTAssertTrue(reaction.finishesRequest)
    }

    func testAPresentedPaywallThatTheCustomerClosesStaysRemote() {
        var policy = SuperwallPaywallFallbackPolicy()
        XCTAssertFalse(policy.react(to: .presented).presentsNativePaywall)
        XCTAssertFalse(policy.react(to: .dismissed).presentsNativePaywall)
        XCTAssertTrue(policy.isFinished)
    }

    func testWebViewFailureAfterPresentShowsTheNativePaywall() {
        var policy = SuperwallPaywallFallbackPolicy()
        _ = policy.react(to: .presented)
        let reaction = policy.react(to: .dismissedAfterLoadFailure)
        XCTAssertTrue(reaction.presentsNativePaywall)
        XCTAssertTrue(reaction.finishesRequest)
    }

    func testDeclineThatLeadsToAnotherPaywallKeepsWaiting() {
        var policy = SuperwallPaywallFallbackPolicy()
        _ = policy.react(to: .presented)
        XCTAssertFalse(policy.react(to: .dismissedForNextPaywall).finishesRequest)
        XCTAssertFalse(policy.isFinished)
        let presented = policy.react(to: .presented)
        XCTAssertFalse(presented.presentsNativePaywall)
        XCTAssertFalse(presented.finishesRequest)
    }

    func testTimeoutWhileAPaywallIsOnScreenDoesNothing() {
        var policy = SuperwallPaywallFallbackPolicy()
        _ = policy.react(to: .presented)
        XCTAssertEqual(policy.react(to: .timedOut), .noEffect)
        XCTAssertFalse(policy.isFinished)
    }

    func testEventsAfterFinishAreIgnored() {
        var policy = SuperwallPaywallFallbackPolicy()
        _ = policy.react(to: .timedOut)
        XCTAssertEqual(policy.react(to: .presented), .noEffect)
        XCTAssertEqual(policy.react(to: .skipped), .noEffect)
    }

    func testDeadlineShowsTheNativePaywallWithoutWaiting() async {
        var showedNative = false
        var finished = false
        let request = SuperwallPaywallRequest(fallback: { showedNative = true }, onFinish: { _ in finished = true })
        request.armDeadline(.seconds(30)) { _ in }
        await request.deadlineTask?.value
        XCTAssertTrue(showedNative)
        XCTAssertTrue(finished)
        XCTAssertTrue(request.isFinished)
    }

    func testASecondRegistrationWhileOneIsInFlightIsIgnored() {
        let requests = SuperwallPaywallRequests()
        var firstNative = 0
        var secondNative = 0
        var secondFinished = 0
        let first = requests.begin(fallback: { firstNative += 1 }, onFinish: {})
        guard case .register(let request) = first else {
            return XCTFail("the first offer should register")
        }
        let second = requests.begin(fallback: { secondNative += 1 }, onFinish: { secondFinished += 1 })
        guard case .alreadyInFlight = second else {
            return XCTFail("a repeated offer must not register or fall back")
        }
        XCTAssertEqual(secondNative, 0)
        XCTAssertEqual(secondFinished, 0)
        XCTAssertTrue(requests.isRequestInFlight)
        request.handle(.skipped)
        XCTAssertEqual(firstNative, 1)
        XCTAssertFalse(requests.isRequestInFlight)
        XCTAssertNil(requests.lateRegistration)
    }

    func testATimedOutRegistrationBlocksAnotherRegisterUntilSuperwallFinishes() {
        let requests = SuperwallPaywallRequests()
        let first = requests.begin(fallback: {}, onFinish: {})
        guard case .register(let request) = first else {
            return XCTFail("the first offer should register")
        }
        request.handle(.timedOut)
        XCTAssertTrue(requests.shouldDismissLatePaywall(of: request))
        XCTAssertTrue(requests.lateRegistration === request)

        var secondNative = 0
        var secondFinished = 0
        let second = requests.begin(
            fallback: { secondNative += 1 },
            onFinish: { secondFinished += 1 }
        )
        guard case .answeredWithNativePaywall = second else {
            return XCTFail("a tap during a late registration uses the native paywall")
        }
        XCTAssertEqual(secondNative, 1)
        XCTAssertEqual(secondFinished, 1)
        XCTAssertTrue(requests.shouldDismissLatePaywall(of: request))

        request.handle(.dismissed)
        XCTAssertNil(requests.lateRegistration)
        let third = requests.begin(fallback: {}, onFinish: {})
        guard case .register = third else {
            return XCTFail("a new offer can register once the earlier one has ended")
        }
    }
}

final class RemotePaywallAppModelTests: XCTestCase {
    func testFreeOfferWaitsForTheRemotePaywall() async throws {
        let remote = RecordingRemotePaywall(defersNativePaywall: true)
        let harness = try TestFixtures.appModel(remotePaywall: remote)
        defer { harness.cleanup() }
        await harness.model.bootstrap()
        harness.model.requestAccess(to: .csvExport)
        XCTAssertEqual(remote.entryPoints, ["csvExport"])
        XCTAssertFalse(harness.model.isPaywallPresented)
        remote.fallback?()
        XCTAssertTrue(harness.model.isPaywallPresented)
        XCTAssertEqual(harness.model.requestedProFeature, .csvExport)
    }

    func testSettingsAndOnboardingUseTheirOwnEntryPoints() async throws {
        let remote = RecordingRemotePaywall(defersNativePaywall: true)
        let harness = try TestFixtures.appModel(remotePaywall: remote)
        defer { harness.cleanup() }
        await harness.model.bootstrap()
        harness.model.presentLifetimeOffer(from: .settings)
        harness.model.presentLifetimeOffer(from: .onboarding)
        XCTAssertEqual(remote.entryPoints, ["settings", "onboarding"])
        XCTAssertNil(harness.model.requestedProFeature)
        XCTAssertFalse(harness.model.isPaywallPresented)
    }

    func testUnresolvedEntitlementUsesTheNativePaywallImmediately() async throws {
        let remote = RecordingRemotePaywall(defersNativePaywall: true)
        let harness = try TestFixtures.appModel(remotePaywall: remote)
        defer { harness.cleanup() }
        harness.purchases.entitlement = .unavailable
        await harness.model.bootstrap()
        harness.model.presentLifetimeOffer(from: .settings)
        XCTAssertTrue(remote.entryPoints.isEmpty)
        XCTAssertTrue(harness.model.isPaywallPresented)
        XCTAssertTrue(harness.model.isEntitlementUnresolved)
    }

    func testProDoesNotOpenEitherPaywall() async throws {
        let remote = RecordingRemotePaywall(defersNativePaywall: true)
        let harness = try TestFixtures.appModel(remotePaywall: remote)
        defer { harness.cleanup() }
        harness.purchases.entitlement = .pro
        await harness.model.bootstrap()
        harness.model.presentLifetimeOffer(from: .settings)
        harness.model.requestAccess(to: .fullHistory)
        XCTAssertTrue(remote.entryPoints.isEmpty)
        XCTAssertFalse(harness.model.isPaywallPresented)
    }

    func testDormantPresenterStillOpensTheNativePaywall() async throws {
        let harness = try TestFixtures.appModel()
        defer { harness.cleanup() }
        await harness.model.bootstrap()
        harness.model.requestAccess(to: .parkingCosts)
        XCTAssertTrue(harness.model.isPaywallPresented)
        XCTAssertEqual(harness.model.requestedProFeature, .parkingCosts)
    }
}

@MainActor
private final class RecordingRemotePaywall: RemotePaywallPresenting {
    var defersNativePaywall: Bool
    private(set) var entryPoints: [String] = []
    var fallback: (@MainActor () -> Void)?

    init(defersNativePaywall: Bool) {
        self.defersNativePaywall = defersNativePaywall
    }

    func presentPaywall(
        entryPoint: String,
        fallback: @escaping @MainActor () -> Void,
        onFinish: @escaping @MainActor () -> Void
    ) {
        entryPoints.append(entryPoint)
        self.fallback = fallback
        if !defersNativePaywall {
            fallback()
            onFinish()
        }
    }
}
