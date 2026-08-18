import Foundation
@preconcurrency import UserNotifications

enum ParkingNotificationCopy {
    static func body(offsetMinutes: Int) -> String {
        offsetMinutes == 0
            ? "Your saved parking meter time has ended."
            : "\(offsetMinutes) minutes remain on your saved parking meter."
    }
}

@MainActor
final class LocalNotificationScheduler: NotificationScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorizationIfNeeded() async throws -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        @unknown default:
            return false
        }
    }

    func schedule(_ reminders: [ReminderPlan], expiry: Date) async throws {
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.offsetMinutes == 0 ? "Parking meter expired" : "Parking meter reminder"
            content.body = ParkingNotificationCopy.body(offsetMinutes: reminder.offsetMinutes)
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            content.userInfo = [
                "session_id": reminder.sessionID.uuidString,
                "meter_expiry": expiry.timeIntervalSince1970
            ]

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: reminder.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: reminder.notificationIdentifier,
                content: content,
                trigger: trigger
            )
            try await center.add(request)
        }
    }

    func cancel(identifiers: [String]) async {
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func authorizationAllowsAlerts() async -> Bool {
        let status = await center.notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional || status == .ephemeral
    }
}
