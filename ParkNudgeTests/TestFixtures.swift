import Foundation
@testable import ParkNudge

enum TestFixtures {
    static let date = Date(timeIntervalSince1970: 1_700_000_000)

    static func session(
        id: UUID = UUID(),
        startedAt: Date = date,
        endedAt: Date? = nil,
        meterExpiresAt: Date? = nil,
        photoRelativePath: String? = nil
    ) -> ParkingSession {
        ParkingSession(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            coordinate: GeoCoordinate(latitude: 40.741_895, longitude: -73.989_308),
            horizontalAccuracy: 7.5,
            locationLabel: "Test Garage",
            floor: "3",
            section: "Blue",
            note: "Near elevator, \"north\" side",
            meterExpiresAt: meterExpiresAt,
            paidAmountMinor: 1_250,
            currencyCode: "USD",
            source: .currentLocation,
            photoRelativePath: photoRelativePath,
            createdAt: startedAt,
            updatedAt: endedAt ?? startedAt
        )
    }
}

struct FixedClock: Clock {
    let now: Date
}
