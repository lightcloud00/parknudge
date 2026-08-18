import Foundation
import SwiftData

enum ParkNudgeSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [ParkingSessionRecord.self, ReminderRequestRecord.self, PhotoMetadataRecord.self]
    }
}

enum ParkNudgeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [ParkNudgeSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum ParkNudgeContainerFactory {
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        if !inMemory,
           let applicationSupportURL = FileManager.default.urls(
               for: .applicationSupportDirectory,
               in: .userDomainMask
           ).first {
            try FileManager.default.createDirectory(
                at: applicationSupportURL,
                withIntermediateDirectories: true
            )
        }
        let schema = Schema(versionedSchema: ParkNudgeSchemaV1.self)
        let configuration = ModelConfiguration(
            "ParkNudge",
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: ParkNudgeMigrationPlan.self,
            configurations: [configuration]
        )
    }
}

@Model
final class ParkingSessionRecord {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var latitude: Double
    var longitude: Double
    var horizontalAccuracy: Double
    var locationLabel: String?
    var floor: String?
    var section: String?
    var note: String?
    var meterExpiresAt: Date?
    var paidAmountMinor: Int64?
    var currencyCode: String?
    var sourceRawValue: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ReminderRequestRecord.session)
    var reminders: [ReminderRequestRecord]

    @Relationship(deleteRule: .cascade, inverse: \PhotoMetadataRecord.session)
    var photos: [PhotoMetadataRecord]

    init(session: ParkingSession) {
        id = session.id
        startedAt = session.startedAt
        endedAt = session.endedAt
        latitude = session.coordinate.latitude
        longitude = session.coordinate.longitude
        horizontalAccuracy = session.horizontalAccuracy
        locationLabel = session.locationLabel
        floor = session.floor
        section = session.section
        note = session.note
        meterExpiresAt = session.meterExpiresAt
        paidAmountMinor = session.paidAmountMinor
        currencyCode = session.currencyCode
        sourceRawValue = session.source.rawValue
        createdAt = session.createdAt
        updatedAt = session.updatedAt
        reminders = []
        photos = []
    }

    func apply(_ session: ParkingSession) {
        startedAt = session.startedAt
        endedAt = session.endedAt
        latitude = session.coordinate.latitude
        longitude = session.coordinate.longitude
        horizontalAccuracy = session.horizontalAccuracy
        locationLabel = session.locationLabel
        floor = session.floor
        section = session.section
        note = session.note
        meterExpiresAt = session.meterExpiresAt
        paidAmountMinor = session.paidAmountMinor
        currencyCode = session.currencyCode
        sourceRawValue = session.source.rawValue
        updatedAt = session.updatedAt
    }

    func domainValue() -> ParkingSession {
        ParkingSession(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            coordinate: GeoCoordinate(latitude: latitude, longitude: longitude),
            horizontalAccuracy: horizontalAccuracy,
            locationLabel: locationLabel,
            floor: floor,
            section: section,
            note: note,
            meterExpiresAt: meterExpiresAt,
            paidAmountMinor: paidAmountMinor,
            currencyCode: currencyCode,
            source: ParkingSource(rawValue: sourceRawValue) ?? .manualPin,
            photoRelativePath: photos.first?.relativePath,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@Model
final class ReminderRequestRecord {
    @Attribute(.unique) var id: UUID
    var fireDate: Date
    var offsetMinutes: Int
    var notificationIdentifier: String
    var createdAt: Date
    var session: ParkingSessionRecord?

    init(reminder: StoredReminder, session: ParkingSessionRecord) {
        id = reminder.id
        fireDate = reminder.fireDate
        offsetMinutes = reminder.offsetMinutes
        notificationIdentifier = reminder.notificationIdentifier
        createdAt = reminder.createdAt
        self.session = session
    }

    func domainValue(sessionID: UUID) -> StoredReminder {
        StoredReminder(
            id: id,
            sessionID: sessionID,
            fireDate: fireDate,
            offsetMinutes: offsetMinutes,
            notificationIdentifier: notificationIdentifier,
            createdAt: createdAt
        )
    }
}

@Model
final class PhotoMetadataRecord {
    @Attribute(.unique) var id: UUID
    var relativePath: String
    var mediaType: String
    var createdAt: Date
    var session: ParkingSessionRecord?

    init(relativePath: String, session: ParkingSessionRecord, createdAt: Date) {
        id = UUID()
        self.relativePath = relativePath
        mediaType = "image/jpeg"
        self.createdAt = createdAt
        self.session = session
    }
}
