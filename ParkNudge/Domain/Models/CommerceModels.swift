import Foundation

enum ProFeature: String, CaseIterable, Identifiable, Sendable {
    case fullHistory
    case customReminders
    case parkingCosts
    case csvExport

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullHistory: "Unlimited parking history"
        case .customReminders: "Custom reminder presets"
        case .parkingCosts: "Parking cost records"
        case .csvExport: "CSV export"
        }
    }

    var symbol: String {
        switch self {
        case .fullHistory: "clock.arrow.circlepath"
        case .customReminders: "bell.badge"
        case .parkingCosts: "dollarsign.circle"
        case .csvExport: "square.and.arrow.up"
        }
    }
}
enum EntitlementState: Equatable, Sendable {
    case loading
    case free
    case pro
    case unavailable

    var isPro: Bool { self == .pro }
}

struct PurchaseProduct: Equatable, Sendable {
    var identifier: String
    var displayName: String
    var displayPrice: String
}

enum PurchaseOutcome: Equatable, Sendable {
    case purchased
    case cancelled
    case pending
}

enum PurchaseServiceError: LocalizedError, Equatable, Sendable {
    case productUnavailable
    case verificationFailed
    case storeUnavailable

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            "Lifetime Pro is not available from the store right now. The free app remains fully usable."
        case .verificationFailed:
            "The purchase could not be verified. Try Restore Purchases or contact support."
        case .storeUnavailable:
            "The App Store could not be reached. The free app remains fully usable."
        }
    }
}

enum FeatureAccessPolicy {
    static let freeHistoryLimit = 3

    static func canUse(_ feature: ProFeature, entitlement: EntitlementState) -> Bool {
        entitlement.isPro
    }
}
