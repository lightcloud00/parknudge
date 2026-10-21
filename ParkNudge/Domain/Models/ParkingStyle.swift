import Foundation

/// Where the driver usually parks, chosen in onboarding or Settings.
///
/// It only decides which details the save screens offer first. Every field
/// stays available whatever is chosen, and nothing is locked behind it.
enum ParkingStyle: String, CaseIterable, Identifiable, Sendable {
    case streetMeter
    case garage
    case lot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .streetMeter: "Street meter"
        case .garage: "Garage"
        case .lot: "Lot"
        }
    }

    var detail: String {
        switch self {
        case .streetMeter: "Set the meter time and get nudged before it runs out."
        case .garage: "Save the floor and section so you find the right level."
        case .lot: "Drop a pin and add a note or a photo."
        }
    }

    var symbol: String {
        switch self {
        case .streetMeter: "timer"
        case .garage: "building.2"
        case .lot: "car"
        }
    }
}

/// The parking editor's detail sections, in the order a style puts first.
enum ParkingDetailSection: CaseIterable, Sendable {
    case details
    case meter
    case photo

    /// With no style chosen the editor keeps its original order.
    static func order(for style: ParkingStyle?) -> [ParkingDetailSection] {
        switch style {
        case .streetMeter: [.meter, .details, .photo]
        case .garage, nil: [.details, .meter, .photo]
        case .lot: [.photo, .details, .meter]
        }
    }
}
