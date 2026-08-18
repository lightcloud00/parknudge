import MapKit

enum DirectionsError: LocalizedError {
    case couldNotOpenMaps

    var errorDescription: String? { "Apple Maps could not open walking directions." }
}

@MainActor
final class AppleMapsDirectionsOpener: DirectionsOpening {
    func openWalkingDirections(to coordinate: GeoCoordinate, label: String?) throws {
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        ))
        let item = MKMapItem(placemark: placemark)
        item.name = label ?? "Parked car"
        let options = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
        guard MKMapItem.openMaps(with: [item], launchOptions: options) else {
            throw DirectionsError.couldNotOpenMaps
        }
    }
}
