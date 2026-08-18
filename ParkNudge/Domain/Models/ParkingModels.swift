import Foundation

struct GeoCoordinate: Codable, Equatable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double
}

enum ParkingSource: String, Codable, CaseIterable, Sendable {
    case currentLocation
    case manualPin
    case searchedPlace
}

struct CapturedLocation: Equatable, Sendable {
    var coordinate: GeoCoordinate
    var horizontalAccuracy: Double
    var capturedAt: Date
    var isReducedAccuracy: Bool
}

struct ParkingSession: Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var coordinate: GeoCoordinate
    var horizontalAccuracy: Double
    var locationLabel: String?
    var floor: String?
    var section: String?
    var note: String?
    var meterExpiresAt: Date?
    var paidAmountMinor: Int64?
    var currencyCode: String?
    var source: ParkingSource
    var photoRelativePath: String?
    var createdAt: Date
    var updatedAt: Date

    var isActive: Bool { endedAt == nil }

    var duration: TimeInterval {
        max(0, (endedAt ?? Date()).timeIntervalSince(startedAt))
    }
}

struct ParkingDraft: Equatable, Sendable {
    var coordinate: GeoCoordinate
    var horizontalAccuracy: Double
    var source: ParkingSource
    var locationLabel = ""
    var floor = ""
    var section = ""
    var note = ""
    var meterExpiresAt: Date?
    var paidAmountMinor: Int64?
    var currencyCode: String
    var photoData: Data?
    var originalPhotoRelativePath: String?
    var removePhoto = false

    static func fallback(currencyCode: String, coordinate: GeoCoordinate) -> ParkingDraft {
        ParkingDraft(
            coordinate: coordinate,
            horizontalAccuracy: -1,
            source: .manualPin,
            currencyCode: currencyCode,
            originalPhotoRelativePath: nil
        )
    }

    static func editing(_ session: ParkingSession) -> ParkingDraft {
        ParkingDraft(
            coordinate: session.coordinate,
            horizontalAccuracy: session.horizontalAccuracy,
            source: session.source,
            locationLabel: session.locationLabel ?? "",
            floor: session.floor ?? "",
            section: session.section ?? "",
            note: session.note ?? "",
            meterExpiresAt: session.meterExpiresAt,
            paidAmountMinor: session.paidAmountMinor,
            currencyCode: session.currencyCode ?? Locale.current.currency?.identifier ?? "USD",
            originalPhotoRelativePath: session.photoRelativePath
        )
    }
}

struct StoredReminder: Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var sessionID: UUID
    var fireDate: Date
    var offsetMinutes: Int
    var notificationIdentifier: String
    var createdAt: Date
}

struct ReminderPlan: Identifiable, Equatable, Hashable, Sendable {
    var id: String { notificationIdentifier }
    var sessionID: UUID
    var fireDate: Date
    var offsetMinutes: Int
    var notificationIdentifier: String
}

enum ParkingRepositoryError: LocalizedError, Equatable {
    case activeSessionExists
    case sessionNotFound
    case persistenceFailure

    var errorDescription: String? {
        switch self {
        case .activeSessionExists:
            return "Finish or replace the current parking session first."
        case .sessionNotFound:
            return "That parking session is no longer available."
        case .persistenceFailure:
            return "Your parking information could not be saved. Please try again."
        }
    }
}

struct ParkingSaveOutcome: Equatable, Sendable {
    var session: ParkingSession
    var archivedSession: ParkingSession?
    var notificationWarning: String?
}
