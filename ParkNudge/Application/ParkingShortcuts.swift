import AppIntents
import Foundation

/// Where a Siri or Shortcuts action lands. Both only open the app: nothing is saved, moved or
/// finished by voice, so a phrase can't change a spot the driver didn't confirm.
enum ParkingShortcutRoute: String, Equatable, Sendable {
    /// The Park tab with the save-spot editor open. Location is still asked only then.
    case parkHere
    /// The Park tab, then walking directions to the saved spot when there is one.
    case findMyCar
}

/// Hands a shortcut's route to the running app. The intent runs before or after the app's views
/// exist (cold or warm launch), so the route waits here until `RootTabView` drains it.
@MainActor
final class ParkingShortcutInbox {
    static let shared = ParkingShortcutInbox()
    static let didEnqueue = Notification.Name("ParkNudge.parkingShortcutDidEnqueue")
    /// `didEnqueue` carries the route's raw value under this key, so an observer can tell which
    /// route arrived even after the running app has already drained it.
    nonisolated static let routeKey = "route"

    private let notificationCenter: NotificationCenter
    private(set) var pending: ParkingShortcutRoute?

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    func enqueue(_ route: ParkingShortcutRoute) {
        pending = route
        notificationCenter.post(name: Self.didEnqueue, object: nil, userInfo: [Self.routeKey: route.rawValue])
    }

    func take() -> ParkingShortcutRoute? {
        defer { pending = nil }
        return pending
    }
}

struct ParkHereIntent: AppIntent {
    static let title: LocalizedStringResource = "Park Here"
    static let description = IntentDescription("Opens ParkNudge ready to save where you parked.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        ParkingShortcutInbox.shared.enqueue(.parkHere)
        return .result()
    }
}

struct FindMyCarIntent: AppIntent {
    static let title: LocalizedStringResource = "Find My Car"
    static let description = IntentDescription("Opens ParkNudge with walking directions back to your saved spot.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        ParkingShortcutInbox.shared.enqueue(.findMyCar)
        return .result()
    }
}

struct ParkNudgeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ParkHereIntent(),
            phrases: [
                "Park here with \(.applicationName)",
                "Save my parking spot in \(.applicationName)",
            ],
            shortTitle: "Park Here",
            systemImageName: "parkingsign.circle.fill"
        )
        AppShortcut(
            intent: FindMyCarIntent(),
            phrases: [
                "Find my car with \(.applicationName)",
                "Where did I park in \(.applicationName)",
            ],
            shortTitle: "Find My Car",
            systemImageName: "figure.walk"
        )
    }
}
