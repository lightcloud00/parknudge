import Foundation

@MainActor
final class AppSettings: ObservableObject {
    @Published var customReminderOffsets: [Int] {
        didSet { defaults.set(customReminderOffsets, forKey: Keys.customReminderOffsets) }
    }

    @Published var currencyCode: String {
        didSet { defaults.set(currencyCode, forKey: Keys.currencyCode) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedOffsets = defaults.array(forKey: Keys.customReminderOffsets) as? [Int]
        customReminderOffsets = ReminderPlanner.normalizedOffsets(savedOffsets ?? [30, 10, 0])
        currencyCode = defaults.string(forKey: Keys.currencyCode)
            ?? Locale.current.currency?.identifier
            ?? "USD"
    }

    /// Marketing version the rating prompt was last *attempted* for. Attempted,
    /// not shown — StoreKit never reports whether it displayed anything.
    var lastReviewRequestVersion: String? {
        get { defaults.string(forKey: Keys.lastReviewRequestVersion) }
        set { defaults.set(newValue, forKey: Keys.lastReviewRequestVersion) }
    }

    /// Set once a new customer saves their free parking session, so deleting
    /// history cannot reopen the free allowance.
    var hasUsedFreeParkingSession: Bool {
        get { defaults.bool(forKey: Keys.hasUsedFreeParkingSession) }
        set { defaults.set(newValue, forKey: Keys.hasUsedFreeParkingSession) }
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
        static let hasUsedFreeParkingSession = "hasUsedFreeParkingSession"
    }
}
