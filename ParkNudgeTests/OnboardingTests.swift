import UIKit
import XCTest
@testable import ParkNudge

final class OnboardingFlowTests: XCTestCase {
    func testShownOnlyToANewDriverWhoHasNotFinishedIt() {
        XCTAssertTrue(OnboardingFlow.shouldPresent(hasCompleted: false, hasParkingHistory: false))
        XCTAssertFalse(OnboardingFlow.shouldPresent(hasCompleted: true, hasParkingHistory: false))
        XCTAssertFalse(OnboardingFlow.shouldPresent(hasCompleted: false, hasParkingHistory: true))
    }

    func testNewDriverWithAMeterSeesAllSixScreens() {
        XCTAssertEqual(walk(hasActiveSession: false, remindersAwaitPermission: true), OnboardingStep.allCases)
    }

    func testFirstSaveWithoutAMeterSkipsTheReminderScreen() {
        XCTAssertEqual(
            walk(hasActiveSession: false, remindersAwaitPermission: false),
            [.promise, .parkingStyle, .location, .firstSave, .pro]
        )
    }

    func testReplayWithASavedSpotPassesOverTheFirstSaveScreens() {
        XCTAssertEqual(
            walk(hasActiveSession: true, remindersAwaitPermission: false),
            [.promise, .parkingStyle, .pro]
        )
    }

    func testPermissionScreensOfferOnlyContinue() {
        XCTAssertFalse(OnboardingStep.location.offersSkip)
        XCTAssertFalse(OnboardingStep.reminders.offersSkip)
        XCTAssertTrue(OnboardingStep.promise.offersSkip)
        XCTAssertTrue(OnboardingStep.parkingStyle.offersSkip)
        XCTAssertTrue(OnboardingStep.firstSave.offersSkip)
    }

    func testPipStatesFollowTheFigmaSlotHints() {
        XCTAssertEqual(
            OnboardingStep.allCases.map(\.pipMood),
            [.idle, .idle, .nudge, .sleepy, .alarm, .happy]
        )
    }

    func testReminderSummaryIsBuiltFromTheOffsetsThatWouldBeScheduled() {
        XCTAssertEqual(
            OnboardingFlow.reminderSummary(offsets: ReminderPlanner.freeOffsets),
            "15 and 5 minutes before, then when it ends"
        )
        XCTAssertEqual(
            OnboardingFlow.reminderSummary(offsets: [5, 30, 15]),
            "30, 15 and 5 minutes before"
        )
        XCTAssertEqual(OnboardingFlow.reminderSummary(offsets: [20]), "20 minutes before")
        XCTAssertEqual(OnboardingFlow.reminderSummary(offsets: [0]), "when it ends")
    }

    func testParkingStyleDecidesWhichEditorSectionLeads() {
        XCTAssertEqual(ParkingDetailSection.order(for: nil), [.details, .meter, .photo])
        XCTAssertEqual(ParkingDetailSection.order(for: .streetMeter).first, .meter)
        XCTAssertEqual(ParkingDetailSection.order(for: .garage).first, .details)
        XCTAssertEqual(ParkingDetailSection.order(for: .lot).first, .photo)
        for style in ParkingStyle.allCases {
            XCTAssertEqual(
                Set(ParkingDetailSection.order(for: style)),
                Set(ParkingDetailSection.allCases),
                "\(style) must keep every section"
            )
        }
    }

    private func walk(hasActiveSession: Bool, remindersAwaitPermission: Bool) -> [OnboardingStep] {
        var steps: [OnboardingStep] = [.promise]
        while let next = OnboardingFlow.step(
            after: steps[steps.count - 1],
            hasActiveSession: hasActiveSession,
            remindersAwaitPermission: remindersAwaitPermission
        ) {
            steps.append(next)
        }
        return steps
    }
}

final class PipMoodTests: XCTestCase {
    private let now = TestFixtures.date

    func testPipNapsWithoutAMeterOrWithLotsOfTimeLeft() {
        XCTAssertEqual(PipMood.forActiveSession(meterExpiry: nil, now: now), .sleepy)
        XCTAssertEqual(PipMood.forActiveSession(meterExpiry: now.addingTimeInterval(2 * 3_600), now: now), .sleepy)
        XCTAssertEqual(PipMood.forActiveSession(meterExpiry: now.addingTimeInterval(15 * 60 + 1), now: now), .sleepy)
    }

    func testPipLeansInDuringTheWarningWindow() {
        XCTAssertEqual(PipMood.forActiveSession(meterExpiry: now.addingTimeInterval(15 * 60), now: now), .nudge)
        XCTAssertEqual(PipMood.forActiveSession(meterExpiry: now.addingTimeInterval(5 * 60 + 1), now: now), .nudge)
    }

    func testPipIsOnAlertFromFiveMinutesLeftAndAfterExpiry() {
        XCTAssertEqual(PipMood.forActiveSession(meterExpiry: now.addingTimeInterval(5 * 60), now: now), .alarm)
        XCTAssertEqual(PipMood.forActiveSession(meterExpiry: now.addingTimeInterval(30), now: now), .alarm)
        XCTAssertEqual(PipMood.forActiveSession(meterExpiry: now.addingTimeInterval(-600), now: now), .alarm)
    }

    /// The image sets are generated from the Figma export; a missing or
    /// misnamed one would render as nothing rather than fail loudly.
    func testEveryMoodHasLightAndDarkVectorArt() {
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        for mood in PipMood.allCases {
            XCTAssertNotNil(UIImage(named: mood.assetName), "\(mood.assetName) light")
            XCTAssertNotNil(UIImage(named: mood.assetName, in: .main, compatibleWith: dark), "\(mood.assetName) dark")
        }
    }
}

@MainActor
final class AppModelOnboardingTests: XCTestCase {
    func testNewDriverIsShownTheIntroduction() throws {
        let harness = try TestFixtures.appModel(onboardingCompleted: false)
        defer { harness.cleanup() }
        XCTAssertTrue(harness.model.isOnboardingPresented)
    }

    func testDriverWithHistoryFromAnEarlierVersionNeverSeesIt() throws {
        let harness = try TestFixtures.appModel(completedSessions: 1, onboardingCompleted: false)
        defer { harness.cleanup() }
        XCTAssertFalse(harness.model.isOnboardingPresented)
        XCTAssertTrue(harness.settings.hasCompletedOnboarding, "Recorded so it stays away after Delete All")
    }

    func testFinishingPersistsSoTheNextLaunchStartsInTheApp() throws {
        let harness = try TestFixtures.appModel(onboardingCompleted: false)
        defer { harness.cleanup() }
        harness.model.completeOnboarding()
        XCTAssertFalse(harness.model.isOnboardingPresented)
        let nextLaunch = AppSettings(defaults: harness.defaults)
        XCTAssertTrue(nextLaunch.hasCompletedOnboarding)
        XCTAssertFalse(OnboardingFlow.shouldPresent(hasCompleted: nextLaunch.hasCompletedOnboarding, hasParkingHistory: false))
    }

    func testSkippingBeforeAnySaveLeavesNoSessionAndNoPermissionRequest() throws {
        let harness = try TestFixtures.appModel(onboardingCompleted: false)
        defer { harness.cleanup() }
        harness.model.completeOnboarding()
        XCTAssertNil(harness.model.activeSession)
        XCTAssertEqual(harness.notifications.authorizationRequests, 0)
        XCTAssertTrue(AppSettings(defaults: harness.defaults).hasCompletedOnboarding)
        XCTAssertFalse(harness.model.isPaywallPresented, "Skipping never opens the offer")
    }

    func testReplayFromSettingsShowsItAgainWithoutForgettingCompletion() throws {
        let harness = try TestFixtures.appModel()
        defer { harness.cleanup() }
        XCTAssertFalse(harness.model.isOnboardingPresented)
        harness.model.replayOnboarding()
        XCTAssertTrue(harness.model.isOnboardingPresented)
        XCTAssertTrue(harness.settings.hasCompletedOnboarding)
        harness.model.completeOnboarding()
        XCTAssertFalse(harness.model.isOnboardingPresented)
    }

    func testFirstSaveWithAMeterWaitsToAskForNotifications() async throws {
        let harness = try TestFixtures.appModel(onboardingCompleted: false)
        defer { harness.cleanup() }
        harness.notifications.allowsAlerts = false

        var draft = await harness.model.newParkingDraft()
        draft.meterExpiresAt = TestFixtures.date.addingTimeInterval(3_600)
        let result = await harness.model.saveFirstSpot(draft: draft)

        XCTAssertEqual(result, .savedAwaitingReminderPermission)
        XCTAssertNotNil(harness.model.activeSession, "The first save is a real session")
        XCTAssertEqual(harness.notifications.authorizationRequests, 0, "iOS must not ask before the explanation")
        XCTAssertTrue(harness.notifications.scheduled.isEmpty)
        XCTAssertNil(harness.model.alertMessage)

        await harness.model.enableMeterReminders()

        XCTAssertEqual(harness.notifications.authorizationRequests, 1)
        XCTAssertEqual(harness.notifications.scheduled.map(\.offsetMinutes), ReminderPlanner.freeOffsets)
        XCTAssertNil(harness.model.alertMessage)
    }

    func testFirstSaveWithoutAMeterNeedsNoReminderScreen() async throws {
        let harness = try TestFixtures.appModel(onboardingCompleted: false)
        defer { harness.cleanup() }
        harness.notifications.allowsAlerts = false

        let draft = await harness.model.newParkingDraft()
        let result = await harness.model.saveFirstSpot(draft: draft)

        XCTAssertEqual(result, .saved)
        XCTAssertEqual(harness.notifications.authorizationRequests, 0)
    }

    func testFirstSaveSchedulesAtOnceWhenAlertsAreAlreadyAllowed() async throws {
        let harness = try TestFixtures.appModel(onboardingCompleted: false)
        defer { harness.cleanup() }

        var draft = await harness.model.newParkingDraft()
        draft.meterExpiresAt = TestFixtures.date.addingTimeInterval(3_600)
        let result = await harness.model.saveFirstSpot(draft: draft)

        XCTAssertEqual(result, .saved)
        XCTAssertEqual(harness.notifications.scheduled.count, ReminderPlanner.freeOffsets.count)
    }

    func testCapturedLocationIsConfirmedAndSaveable() async throws {
        let harness = try TestFixtures.appModel(onboardingCompleted: false)
        defer { harness.cleanup() }

        let draft = await harness.model.newParkingDraft()

        XCTAssertEqual(draft.locationConfirmation, .captured)
        XCTAssertEqual(draft.source, .currentLocation)
        XCTAssertEqual(draft.coordinate, GeoCoordinate(latitude: 40, longitude: -74))
        let result = await harness.model.saveFirstSpot(draft: draft)
        XCTAssertEqual(result, .saved)
        XCTAssertEqual(harness.model.activeSession?.coordinate, draft.coordinate)
        XCTAssertEqual(harness.model.activeSession?.source, .currentLocation)
    }

    func testFailedLookupsStayUnconfirmedUntilThePinIsConfirmed() async throws {
        let cases: [(ModelLocationFake.Script, LocationAcquisitionFailure)] = [
            (.failure(.denied), .denied),
            (.failure(.restricted), .restricted),
            (.failure(.servicesDisabled), .servicesDisabled),
            (.failure(.unavailable), .unavailable),
            (.failure(.requestInProgress), .requestInProgress),
            (.genericFailure, .unavailable)
        ]
        for (script, failure) in cases {
            let harness = try TestFixtures.appModel(onboardingCompleted: false)
            defer { harness.cleanup() }
            harness.location.script = script

            var draft = await harness.model.newParkingDraft()
            draft.note = "Near the stairs"
            draft.meterExpiresAt = TestFixtures.date.addingTimeInterval(1_800)

            XCTAssertEqual(draft.locationConfirmation, .needsConfirmation(failure), "\(failure)")
            XCTAssertEqual(draft.coordinate, ParkingDraft.unconfirmedPlaceholderCoordinate)
            let blocked = await harness.model.saveFirstSpot(draft: draft)
            XCTAssertEqual(blocked, .failed, "\(failure)")
            XCTAssertNil(harness.model.activeSession, "\(failure)")
            XCTAssertNil(harness.model.alertMessage, "\(failure)")

            draft.confirmExplicitSelection(source: .manualPin)
            XCTAssertEqual(draft.coordinate, ParkingDraft.unconfirmedPlaceholderCoordinate)
            let saved = await harness.model.saveFirstSpot(draft: draft)
            XCTAssertEqual(saved, .saved, "\(failure)")
            XCTAssertEqual(harness.model.activeSession?.coordinate, ParkingDraft.unconfirmedPlaceholderCoordinate)
            XCTAssertEqual(harness.model.activeSession?.source, .manualPin)
            XCTAssertEqual(harness.model.activeSession?.note, "Near the stairs")
            XCTAssertEqual(harness.model.activeSession?.meterExpiresAt, draft.meterExpiresAt)
        }
    }

    func testMovingTheCoordinateWithoutConfirmingDoesNotSave() async throws {
        let harness = try TestFixtures.appModel(onboardingCompleted: false)
        defer { harness.cleanup() }
        harness.location.script = .failure(.denied)

        var draft = await harness.model.newParkingDraft()
        draft.coordinate = GeoCoordinate(latitude: 41.2, longitude: -73.5)
        draft.source = .manualPin
        draft.note = "Not yet"
        let blocked = await harness.model.saveFirstSpot(draft: draft)

        XCTAssertEqual(blocked, .failed)
        XCTAssertNil(harness.model.activeSession)
        draft.confirmExplicitSelection(source: .manualPin)
        XCTAssertEqual(draft.coordinate.latitude, 41.2)
        let saved = await harness.model.saveFirstSpot(draft: draft)
        XCTAssertEqual(saved, .saved)
        XCTAssertEqual(harness.model.activeSession?.coordinate.latitude, 41.2)
        XCTAssertEqual(harness.model.activeSession?.note, "Not yet")
        XCTAssertEqual(harness.model.activeSession?.source, .manualPin)
    }

    func testRetryKeepsNotesAndMeterThroughFailureAndSuccess() async throws {
        let harness = try TestFixtures.appModel(onboardingCompleted: false)
        defer { harness.cleanup() }
        harness.location.script = .failure(.denied)
        var draft = await harness.model.newParkingDraft()
        let deadline = TestFixtures.date.addingTimeInterval(1_800)
        draft.note = "Row B"
        draft.floor = "P2"
        draft.locationLabel = "Market St"
        draft.meterExpiresAt = deadline

        harness.location.script = .failure(.unavailable)
        let failedRetry = await harness.model.retryParkingLocation(keeping: draft)

        XCTAssertEqual(failedRetry.note, "Row B")
        XCTAssertEqual(failedRetry.floor, "P2")
        XCTAssertEqual(failedRetry.locationLabel, "Market St")
        XCTAssertEqual(failedRetry.meterExpiresAt, deadline)
        XCTAssertEqual(failedRetry.locationConfirmation, .needsConfirmation(.unavailable))
        XCTAssertNil(harness.model.activeSession)
        XCTAssertEqual(harness.location.captureCount, 2)

        harness.location.script = .fix
        harness.location.coordinate = GeoCoordinate(latitude: 37.7, longitude: -122.4)
        let fixed = await harness.model.retryParkingLocation(keeping: failedRetry)

        XCTAssertEqual(fixed.note, "Row B")
        XCTAssertEqual(fixed.floor, "P2")
        XCTAssertEqual(fixed.locationLabel, "Market St")
        XCTAssertEqual(fixed.meterExpiresAt, deadline)
        XCTAssertEqual(fixed.locationConfirmation, .captured)
        XCTAssertEqual(fixed.coordinate.latitude, 37.7)
        let result = await harness.model.saveFirstSpot(draft: fixed)
        XCTAssertEqual(result, .saved)
        XCTAssertEqual(harness.model.activeSession?.coordinate.latitude, 37.7)
        XCTAssertEqual(harness.model.activeSession?.note, "Row B")
        XCTAssertEqual(harness.model.activeSession?.meterExpiresAt, deadline)
    }

    func testFailedRetryKeepsAConfirmedPin() async throws {
        let harness = try TestFixtures.appModel(onboardingCompleted: false)
        defer { harness.cleanup() }
        var draft = await harness.model.newParkingDraft()
        draft.note = "Keep"
        let captured = draft.coordinate

        harness.location.script = .failure(.restricted)
        let retried = await harness.model.retryParkingLocation(keeping: draft)

        XCTAssertEqual(retried.locationConfirmation, .captured)
        XCTAssertEqual(retried.coordinate, captured)
        XCTAssertEqual(retried.note, "Keep")
        XCTAssertNil(harness.model.activeSession)
    }

    func testUnconfirmedSaveDoesNotReplaceAnExistingSpot() async throws {
        let harness = try TestFixtures.appModel()
        defer { harness.cleanup() }
        try harness.repository.create(TestFixtures.session())
        await harness.model.reload()
        let original = try XCTUnwrap(harness.model.activeSession)
        harness.location.script = .failure(.denied)

        let draft = await harness.model.newParkingDraft()
        let replaced = await harness.model.saveNew(draft: draft, replacingActive: true)

        XCTAssertFalse(replaced)
        XCTAssertEqual(harness.model.activeSession, original)
        XCTAssertEqual(harness.model.completedSessions.count, 0)
        XCTAssertEqual(
            harness.model.alertMessage,
            ParkingLocationError.unconfirmedLocation.localizedDescription
        )
    }

    func testUnconfirmedUpdateLeavesTheSavedSpot() async throws {
        let harness = try TestFixtures.appModel()
        defer { harness.cleanup() }
        let draft = await harness.model.newParkingDraft()
        XCTAssertTrue(await harness.model.saveNew(draft: draft, replacingActive: false))
        let original = try XCTUnwrap(harness.model.activeSession)
        var unconfirmed = ParkingDraft.unconfirmedPlaceholder(currencyCode: "USD", failure: .denied)
        unconfirmed.note = "Should not land"

        let updated = await harness.model.updateActive(draft: unconfirmed)

        XCTAssertFalse(updated)
        XCTAssertEqual(harness.model.activeSession, original)
        XCTAssertEqual(
            harness.model.alertMessage,
            ParkingLocationError.unconfirmedLocation.localizedDescription
        )
    }

    func testParkingStyleIsRemembered() throws {
        let harness = try TestFixtures.appModel()
        defer { harness.cleanup() }
        harness.settings.parkingStyle = .garage
        XCTAssertEqual(AppSettings(defaults: harness.defaults).parkingStyle, .garage)
        harness.settings.parkingStyle = nil
        XCTAssertNil(AppSettings(defaults: harness.defaults).parkingStyle)
    }
}
