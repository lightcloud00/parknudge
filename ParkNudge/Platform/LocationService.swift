import CoreLocation
import Foundation

enum LocationServiceError: LocalizedError, Equatable {
    case servicesDisabled
    case denied
    case restricted
    case unavailable
    case requestInProgress

    var errorDescription: String? {
        switch self {
        case .servicesDisabled: "Location Services are off. Move the map pin to save manually."
        case .denied: "Location access is denied. Move the map pin to save manually."
        case .restricted: "Location access is restricted. Move the map pin to save manually."
        case .unavailable: "A current location was not available. Move the map pin to save manually."
        case .requestInProgress: "A location request is already in progress."
        }
    }
}

@MainActor
final class OneShotLocationProvider: NSObject, LocationProviding, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CapturedLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func captureCurrentLocation() async throws -> CapturedLocation {
        guard continuation == nil else { throw LocationServiceError.requestInProgress }
        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationServiceError.servicesDisabled
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            continueForAuthorization(manager.authorizationStatus)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }
        continueForAuthorization(manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations
            .filter({ $0.horizontalAccuracy >= 0 })
            .sorted(by: { $0.timestamp > $1.timestamp })
            .first else {
            complete(with: .failure(LocationServiceError.unavailable))
            return
        }

        manager.stopUpdatingLocation()
        complete(with: .success(CapturedLocation(
            coordinate: GeoCoordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            ),
            horizontalAccuracy: location.horizontalAccuracy,
            capturedAt: location.timestamp,
            isReducedAccuracy: manager.accuracyAuthorization == .reducedAccuracy
        )))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        manager.stopUpdatingLocation()
        complete(with: .failure(LocationServiceError.unavailable))
    }

    private func continueForAuthorization(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied:
            complete(with: .failure(LocationServiceError.denied))
        case .restricted:
            complete(with: .failure(LocationServiceError.restricted))
        @unknown default:
            complete(with: .failure(LocationServiceError.unavailable))
        }
    }

    private func complete(with result: Result<CapturedLocation, Error>) {
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(with: result)
    }
}
