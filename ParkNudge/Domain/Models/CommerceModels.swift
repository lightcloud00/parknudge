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

    /// Shorter wording for the paywall's comparison rows, where the feature
    /// name sits beside two narrow columns.
    var comparisonTitle: String {
        switch self {
        case .fullHistory: "Finished sessions shown"
        case .customReminders: "Meter reminders"
        case .parkingCosts: "Parking cost records"
        case .csvExport: "CSV export"
        }
    }

    /// What free already gives for this feature, or `nil` when free gives
    /// nothing. Derived from the policies themselves so the paywall cannot
    /// drift away from what the app actually enforces.
    var freeAllowance: String? {
        switch self {
        case .fullHistory: "\(FeatureAccessPolicy.freeHistoryLimit)"
        case .customReminders: ReminderPlanner.freeOffsets.map(String.init).joined(separator: "/")
        case .parkingCosts, .csvExport: nil
        }
    }

    /// The Pro column's wording, or `nil` for a plain checkmark.
    var proAllowance: String? {
        switch self {
        case .fullHistory: "All"
        case .customReminders: "Yours"
        case .parkingCosts, .csvExport: nil
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

/// An unavailable or unverified app transaction cannot establish that a
/// customer is ineligible for their original parking features. A verified
/// sandbox or Xcode app transaction can: no original App Store download exists.
enum LegacyParkingAccessState: Equatable, Sendable {
    case unknown
    case eligible
    case ineligible
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
            "Lifetime Pro is not available from the store right now. Your saved parking details remain available."
        case .verificationFailed:
            "The purchase could not be verified. Try Restore Purchases or contact support."
        case .storeUnavailable:
            "The App Store could not be reached. Your saved parking details remain available."
        }
    }
}

enum FeatureAccessPolicy {
    static let freeHistoryLimit = 3

    static func canUse(_ feature: ProFeature, entitlement: EntitlementState) -> Bool {
        entitlement.isPro
    }
}

/// Existing App Store customers retain their original parking loop. On iOS,
/// AppTransaction.originalAppVersion is the original CFBundleVersion, not the
/// marketing version. Only a verified production app transaction may call
/// `includes(originalBuild:)`; `state(...)` applies that rule.
enum LegacyParkingAccessPolicy {
    static let lastFreeBuild = 2
    static let bundleIdentifier = "com.gusdigitalsolutions.parknudge"

    /// Classifies the outcome of an App Store app transaction lookup.
    ///
    /// - An unverified transaction, or one for another bundle, decides
    ///   nothing: `.unknown`, so a store problem never revokes access.
    /// - A verified sandbox or Xcode transaction (TestFlight, App Review, local
    ///   StoreKit testing) is never an original App Store customer:
    ///   `.ineligible`. Restore Purchases then reports that nothing was found
    ///   instead of a store verification failure.
    /// - A verified production transaction is eligible only for original
    ///   builds 1 through `lastFreeBuild`.
    nonisolated static func state(
        isVerified: Bool,
        bundleID: String,
        isProduction: Bool,
        originalAppVersion: String
    ) -> LegacyParkingAccessState {
        guard isVerified, bundleID == bundleIdentifier else { return .unknown }
        guard isProduction else { return .ineligible }
        return includes(originalBuild: originalAppVersion) ? .eligible : .ineligible
    }

    nonisolated static func includes(originalBuild: String) -> Bool {
        guard !originalBuild.isEmpty,
              originalBuild.allSatisfy({ $0.isASCII && $0.isNumber }),
              let build = Int(originalBuild) else { return false }
        return (1...lastFreeBuild).contains(build)
    }
}
