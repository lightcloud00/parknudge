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

/// Whether a draft's coordinate may be stored as the user's parking spot.
///
/// This is independent of the numbers. A genuine selection is saved even when
/// it happens to equal the unconfirmed placeholder.
enum LocationConfirmation: Equatable, Sendable {
    /// Core Location returned this coordinate.
    case captured
    /// The user chose this coordinate, on the map, from search, or with an accessible control.
    case explicitSelection
    /// Capture failed. The coordinate is only a map placeholder.
    case needsConfirmation(LocationAcquisitionFailure)

    var isConfirmed: Bool {
        switch self {
        case .captured, .explicitSelection: true
        case .needsConfirmation: false
        }
    }

    var acquisitionFailure: LocationAcquisitionFailure? {
        if case .needsConfirmation(let failure) = self { failure } else { nil }
    }
}

/// A location capture that did not produce a coordinate the user has accepted.
enum LocationAcquisitionFailure: Equatable, Sendable {
    case servicesDisabled
    case denied
    case restricted
    /// Timeout and every other capture failure that is not a permission state.
    case unavailable
    case requestInProgress

    /// The same sentences `LocationServiceError` shows, so a failed lookup
    /// does not invent a second explanation.
    var guidance: String {
        switch self {
        case .servicesDisabled:
            "Location Services are off. Move the map pin to save manually."
        case .denied:
            "Location access is denied. Move the map pin to save manually."
        case .restricted:
            "Location access is restricted. Move the map pin to save manually."
        case .unavailable:
            "A current location was not available. Move the map pin to save manually."
        case .requestInProgress:
            "A location request is already in progress."
        }
    }
}

enum ParkingLocationError: LocalizedError, Equatable {
    /// The draft still carries a placeholder from a failed lookup.
    case unconfirmedLocation

    var errorDescription: String? {
        switch self {
        case .unconfirmedLocation:
            "Choose where you parked before saving. Retry location, search for a place, or confirm the pin on the map."
        }
    }
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
    /// Defaults to an explicit selection so a draft built by a caller that
    /// already chose a coordinate stays saveable. Failed lookups opt out.
    var locationConfirmation: LocationConfirmation = .explicitSelection

    /// Continental US center. It is a map placeholder after a failed lookup,
    /// never proof that the user parked there.
    static let unconfirmedPlaceholderCoordinate = GeoCoordinate(latitude: 39.8283, longitude: -98.5795)

    /// A coordinate the caller already chose. A failed lookup does not use this.
    static func fallback(currencyCode: String, coordinate: GeoCoordinate) -> ParkingDraft {
        ParkingDraft(
            coordinate: coordinate,
            horizontalAccuracy: -1,
            source: .manualPin,
            currencyCode: currencyCode,
            originalPhotoRelativePath: nil,
            locationConfirmation: .explicitSelection
        )
    }

    static func unconfirmedPlaceholder(
        currencyCode: String,
        failure: LocationAcquisitionFailure
    ) -> ParkingDraft {
        ParkingDraft(
            coordinate: unconfirmedPlaceholderCoordinate,
            horizontalAccuracy: -1,
            source: .manualPin,
            currencyCode: currencyCode,
            originalPhotoRelativePath: nil,
            locationConfirmation: .needsConfirmation(failure)
        )
    }

    /// Records that the user chose the current coordinate. The coordinate is
    /// kept, including when it is still the unconfirmed placeholder.
    mutating func confirmExplicitSelection(source: ParkingSource) {
        self.source = source
        if source != .currentLocation {
            horizontalAccuracy = -1
        }
        locationConfirmation = .explicitSelection
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
            originalPhotoRelativePath: session.photoRelativePath,
            locationConfirmation: session.source == .currentLocation ? .captured : .explicitSelection
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
    /// The meter's reminders are stored but not scheduled, because the save
    /// asked not to raise the notification prompt and alerts are not allowed
    /// yet. `ParkingCoordinator.scheduleActiveReminders` schedules them.
    var remindersAwaitPermission = false
}
