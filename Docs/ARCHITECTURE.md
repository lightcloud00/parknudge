# Architecture

## Layers

```text
SwiftUI views
    ↓
AppModel (@MainActor state and feature access)
    ↓
ParkingCoordinator (save, replace, edit, finish, delete transitions)
    ↓
Protocol boundaries
    ├── ParkingRepository → SwiftDataParkingRepository
    ├── LocationProviding → OneShotLocationProvider
    ├── NotificationScheduling → LocalNotificationScheduler
    ├── PhotoStoring → ApplicationSupportPhotoStore
    ├── DirectionsOpening → AppleMapsDirectionsOpener
    ├── PurchaseProviding → StoreKitPurchaseService
    ├── CSVExporting → LocalCSVExporter
    └── Clock → SystemClock
```

## Persistence

`ParkNudgeSchemaV1` contains:

- `ParkingSessionRecord` for active and completed sessions
- `ReminderRequestRecord` for deterministic local-notification metadata
- `PhotoMetadataRecord` for an associated relative JPEG path and media type

Relationships use cascade deletion. Photo bytes live under Application Support rather than SwiftData. The coordinator removes files after repository deletion and performs orphan cleanup at launch.

Money is stored as an integer number of minor units plus the session’s ISO currency code. CSV exports contain no photo bytes or internal photo path.

## Invariants

- The repository refuses a second active session.
- Confirmed replacement archives the current session and creates one new active session.
- Notification identifiers are `parknudge.meter.<session-uuid>.<offset>`.
- Old reminders are cancelled and replaced when the meter changes.
- Scheduling failure returns a warning after persistence; it cannot roll back the parking session.
- Entitlement preferences are never cached as ownership proof.

## Privacy and capabilities

The target includes When-In-Use location and camera purpose strings, the time-sensitive notification entitlement, and in-app purchase capability. It has no background modes, push entitlement, tracking declaration, or third-party SDK.
