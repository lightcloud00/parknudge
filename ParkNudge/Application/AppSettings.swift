import Foundation

@MainActor
final class AppSettings: ObservableObject {
    @Published var customReminderOffsets: [Int] {
        didSet { defaults.set(customReminderOffsets, forKey: Keys.customReminderOffsets) }
    }

    @Published var currencyCode: String {
        didSet { defaults.set(currencyCode, forKey: Keys.currencyCode) }
    }

    /// Decides which details the save screens offer first. `nil` until the
    /// driver picks one, which keeps the editor's original order.
    @Published var parkingStyle: ParkingStyle? {
        didSet { defaults.set(parkingStyle?.rawValue, forKey: Keys.parkingStyle) }
    }

    /// Set when the introduction is finished or skipped. Replaying it from
    /// Settings does not clear it, so a replay can never come back on launch.
    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedOffsets = defaults.array(forKey: Keys.customReminderOffsets) as? [Int]
        customReminderOffsets = ReminderPlanner.normalizedOffsets(savedOffsets ?? [30, 10, 0])
        currencyCode = defaults.string(forKey: Keys.currencyCode)
            ?? Locale.current.currency?.identifier
            ?? "USD"
        parkingStyle = defaults.string(forKey: Keys.parkingStyle).flatMap(ParkingStyle.init(rawValue:))
        hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
    }

    /// Marketing version the rating prompt was last *attempted* for. Attempted,
    /// not shown — StoreKit never reports whether it displayed anything.
    var lastReviewRequestVersion: String? {
        get { defaults.string(forKey: Keys.lastReviewRequestVersion) }
        set { defaults.set(newValue, forKey: Keys.lastReviewRequestVersion) }
    }

    var lastReviewRequestDate: Date? {
        get { defaults.object(forKey: Keys.lastReviewRequestDate) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastReviewRequestDate) }
    }

    private enum Keys {
        static let customReminderOffsets = "customReminderOffsets"
        static let currencyCode = "currencyCode"
        static let lastReviewRequestVersion = "lastReviewRequestVersion"
        static let lastReviewRequestDate = "lastReviewRequestDate"
        static let parkingStyle = "parkingStyle"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }
}
