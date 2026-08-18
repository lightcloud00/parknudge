import MapKit

struct PlaceSuggestion: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let detail: String
    let coordinate: GeoCoordinate
}

@MainActor
final class PlaceSearchModel: ObservableObject {
    @Published private(set) var results: [PlaceSuggestion] = []
    @Published private(set) var isSearching = false
    @Published var errorMessage: String?

    func clearResults() {
        results = []
    }

    func search(query: String, near coordinate: GeoCoordinate) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }

        isSearching = true
        defer { isSearching = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
        do {
            let response = try await MKLocalSearch(request: request).start()
            results = response.mapItems.prefix(6).map { item in
                PlaceSuggestion(
                    name: item.name ?? "Map result",
                    detail: item.placemark.title ?? "",
                    coordinate: GeoCoordinate(
                        latitude: item.placemark.coordinate.latitude,
                        longitude: item.placemark.coordinate.longitude
                    )
                )
            }
            if results.isEmpty { errorMessage = "No matching places were found." }
        } catch {
            errorMessage = "Place search is unavailable right now. You can still move the map pin."
        }
    }
}
