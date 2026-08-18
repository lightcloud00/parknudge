import Foundation
import SwiftData

@MainActor
final class SwiftDataParkingRepository: ParkingRepository {
    private let context: ModelContext

    init(container: ModelContainer) {
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    func activeSession() throws -> ParkingSession? {
        let records = try allRecords().filter { $0.endedAt == nil }
        guard records.count <= 1 else { throw ParkingRepositoryError.persistenceFailure }
        return records.first?.domainValue()
    }

    func completedSessions() throws -> [ParkingSession] {
        try allRecords()
            .filter { $0.endedAt != nil }
            .sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }
            .map { $0.domainValue() }
    }

    func create(_ session: ParkingSession) throws {
        guard try activeSession() == nil else { throw ParkingRepositoryError.activeSessionExists }
        let record = ParkingSessionRecord(session: session)
        context.insert(record)
        synchronizePhoto(for: record, relativePath: session.photoRelativePath, createdAt: session.createdAt)
        try save()
    }

    func replaceActive(with session: ParkingSession, at date: Date) throws -> ParkingSession? {
        let active = try activeRecord()
        if let active {
            active.endedAt = date
            active.updatedAt = date
        }

        let newRecord = ParkingSessionRecord(session: session)
        context.insert(newRecord)
        synchronizePhoto(for: newRecord, relativePath: session.photoRelativePath, createdAt: session.createdAt)
        try save()
        return active?.domainValue()
    }

    func update(_ session: ParkingSession) throws {
        guard let record = try record(id: session.id) else { throw ParkingRepositoryError.sessionNotFound }
        record.apply(session)
        synchronizePhoto(for: record, relativePath: session.photoRelativePath, createdAt: session.updatedAt)
        try save()
    }

    func finish(sessionID: UUID, at date: Date) throws {
        guard let record = try record(id: sessionID) else { throw ParkingRepositoryError.sessionNotFound }
        record.endedAt = date
        record.updatedAt = date
        try save()
    }

    func delete(sessionID: UUID) throws -> ParkingSession? {
        guard let record = try record(id: sessionID) else { return nil }
        let session = record.domainValue()
        context.delete(record)
        try save()
        return session
    }

    func deleteAll() throws -> [ParkingSession] {
        let records = try allRecords()
        let sessions = records.map { $0.domainValue() }
        records.forEach(context.delete)
        try save()
        return sessions
    }

    func reminders(sessionID: UUID) throws -> [StoredReminder] {
        guard let record = try record(id: sessionID) else { return [] }
        return record.reminders
            .map { $0.domainValue(sessionID: sessionID) }
            .sorted { $0.fireDate < $1.fireDate }
    }

    func replaceReminders(sessionID: UUID, with reminders: [StoredReminder]) throws {
        guard let record = try record(id: sessionID) else { throw ParkingRepositoryError.sessionNotFound }
        let old = record.reminders
        record.reminders = []
        old.forEach(context.delete)

        for reminder in reminders {
            let reminderRecord = ReminderRequestRecord(reminder: reminder, session: record)
            context.insert(reminderRecord)
            record.reminders.append(reminderRecord)
        }
        try save()
    }

    private func allRecords() throws -> [ParkingSessionRecord] {
        do {
            return try context.fetch(FetchDescriptor<ParkingSessionRecord>())
        } catch {
            throw ParkingRepositoryError.persistenceFailure
        }
    }

    private func activeRecord() throws -> ParkingSessionRecord? {
        let records = try allRecords().filter { $0.endedAt == nil }
        guard records.count <= 1 else { throw ParkingRepositoryError.persistenceFailure }
        return records.first
    }

    private func record(id: UUID) throws -> ParkingSessionRecord? {
        try allRecords().first { $0.id == id }
    }

    private func synchronizePhoto(for record: ParkingSessionRecord, relativePath: String?, createdAt: Date) {
        if record.photos.first?.relativePath == relativePath { return }
        let old = record.photos
        record.photos = []
        old.forEach(context.delete)
        if let relativePath {
            let photo = PhotoMetadataRecord(relativePath: relativePath, session: record, createdAt: createdAt)
            context.insert(photo)
            record.photos = [photo]
        }
    }

    private func save() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw ParkingRepositoryError.persistenceFailure
        }
    }
}
