import Foundation

@MainActor
final class ParkingCoordinator {
    private let repository: ParkingRepository
    private let notifications: NotificationScheduling
    private let photos: PhotoStoring
    private let clock: Clock

    init(
        repository: ParkingRepository,
        notifications: NotificationScheduling,
        photos: PhotoStoring,
        clock: Clock
    ) {
        self.repository = repository
        self.notifications = notifications
        self.photos = photos
        self.clock = clock
    }

    func saveNew(
        draft: ParkingDraft,
        replacingActive: Bool,
        reminderOffsets: [Int]
    ) async throws -> ParkingSaveOutcome {
        let now = clock.now
        let id = UUID()
        var photoPath: String?

        if let data = draft.photoData {
            photoPath = try photos.storeJPEG(data: data, sessionID: id)
        }

        let session = makeSession(id: id, draft: draft, photoPath: photoPath, now: now)
        let previousActive = try repository.activeSession()

        do {
            if previousActive != nil {
                guard replacingActive else { throw ParkingRepositoryError.activeSessionExists }
                _ = try repository.replaceActive(with: session, at: now)
            } else {
                try repository.create(session)
            }
        } catch {
            if let photoPath { try? photos.delete(relativePath: photoPath) }
            throw error
        }

        if let previousActive {
            await cancelReminders(for: previousActive.id)
        }
        let warning = await synchronizeReminders(for: session, offsets: reminderOffsets)
        return ParkingSaveOutcome(
            session: session,
            archivedSession: previousActive.map { archived in
                var archived = archived
                archived.endedAt = now
                archived.updatedAt = now
                return archived
            },
            notificationWarning: warning
        )
    }

    func updateActive(draft: ParkingDraft, reminderOffsets: [Int]) async throws -> ParkingSaveOutcome {
        guard var session = try repository.activeSession() else {
            throw ParkingRepositoryError.sessionNotFound
        }

        let oldPhotoPath = session.photoRelativePath
        var newPhotoPath = draft.removePhoto ? nil : (draft.originalPhotoRelativePath ?? oldPhotoPath)
        if let data = draft.photoData {
            newPhotoPath = try photos.storeJPEG(data: data, sessionID: session.id)
        }

        session.coordinate = draft.coordinate
        session.horizontalAccuracy = draft.horizontalAccuracy
        session.source = draft.source
        session.locationLabel = draft.locationLabel.nilIfBlank
        session.floor = draft.floor.nilIfBlank
        session.section = draft.section.nilIfBlank
        session.note = draft.note.nilIfBlank
        session.meterExpiresAt = draft.meterExpiresAt
        session.paidAmountMinor = draft.paidAmountMinor
        session.currencyCode = draft.paidAmountMinor == nil ? nil : draft.currencyCode
        session.photoRelativePath = newPhotoPath
        session.updatedAt = clock.now

        do {
            try repository.update(session)
        } catch {
            if let newPhotoPath, newPhotoPath != oldPhotoPath {
                try? photos.delete(relativePath: newPhotoPath)
            }
            throw error
        }

        if let oldPhotoPath, oldPhotoPath != newPhotoPath {
            try? photos.delete(relativePath: oldPhotoPath)
        }
        let warning = await synchronizeReminders(for: session, offsets: reminderOffsets)
        return ParkingSaveOutcome(session: session, archivedSession: nil, notificationWarning: warning)
    }

    func finishActive() async throws -> ParkingSession {
        guard var session = try repository.activeSession() else {
            throw ParkingRepositoryError.sessionNotFound
        }
        let now = clock.now
        try repository.finish(sessionID: session.id, at: now)
        await cancelReminders(for: session.id)
        session.endedAt = now
        session.updatedAt = now
        return session
    }

    func delete(sessionID: UUID) async throws {
        let reminders = try repository.reminders(sessionID: sessionID)
        let removed = try repository.delete(sessionID: sessionID)
        await notifications.cancel(identifiers: reminders.map(\.notificationIdentifier))
        if let path = removed?.photoRelativePath { try? photos.delete(relativePath: path) }
    }

    func deleteAll() async throws {
        let active = try repository.activeSession()
        let completed = try repository.completedSessions()
        let identifiers = try ([active].compactMap { $0 } + completed).flatMap { session in
            try repository.reminders(sessionID: session.id).map(\.notificationIdentifier)
        }
        let sessions = try repository.deleteAll()
        await notifications.cancel(identifiers: identifiers)
        for path in sessions.compactMap(\.photoRelativePath) {
            try? photos.delete(relativePath: path)
        }
        try? photos.removeOrphans(keeping: [])
    }

    func cleanOrphanedPhotos() throws {
        let sessions = ([try repository.activeSession()].compactMap { $0 } + (try repository.completedSessions()))
        try photos.removeOrphans(keeping: Set(sessions.compactMap(\.photoRelativePath)))
    }

    private func makeSession(id: UUID, draft: ParkingDraft, photoPath: String?, now: Date) -> ParkingSession {
        ParkingSession(
            id: id,
            startedAt: now,
            endedAt: nil,
            coordinate: draft.coordinate,
            horizontalAccuracy: draft.horizontalAccuracy,
            locationLabel: draft.locationLabel.nilIfBlank,
            floor: draft.floor.nilIfBlank,
            section: draft.section.nilIfBlank,
            note: draft.note.nilIfBlank,
            meterExpiresAt: draft.meterExpiresAt,
            paidAmountMinor: draft.paidAmountMinor,
            currencyCode: draft.paidAmountMinor == nil ? nil : draft.currencyCode,
            source: draft.source,
            photoRelativePath: photoPath,
            createdAt: now,
            updatedAt: now
        )
    }

    private func synchronizeReminders(for session: ParkingSession, offsets: [Int]) async -> String? {
        let existing = (try? repository.reminders(sessionID: session.id)) ?? []
        await notifications.cancel(identifiers: existing.map(\.notificationIdentifier))

        guard let expiry = session.meterExpiresAt else {
            try? repository.replaceReminders(sessionID: session.id, with: [])
            return nil
        }

        let plans = ReminderPlanner.plans(
            sessionID: session.id,
            expiry: expiry,
            offsets: offsets,
            now: clock.now
        )
        let stored = plans.map {
            StoredReminder(
                id: UUID(),
                sessionID: session.id,
                fireDate: $0.fireDate,
                offsetMinutes: $0.offsetMinutes,
                notificationIdentifier: $0.notificationIdentifier,
                createdAt: clock.now
            )
        }
        try? repository.replaceReminders(sessionID: session.id, with: stored)

        do {
            guard try await notifications.requestAuthorizationIfNeeded() else {
                return "Parking was saved, but notifications are turned off."
            }
            try await notifications.schedule(plans, expiry: expiry)
            return nil
        } catch {
            return "Parking was saved, but one or more meter reminders could not be scheduled."
        }
    }

    private func cancelReminders(for sessionID: UUID) async {
        let reminders = (try? repository.reminders(sessionID: sessionID)) ?? []
        await notifications.cancel(identifiers: reminders.map(\.notificationIdentifier))
        try? repository.replaceReminders(sessionID: sessionID, with: [])
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
