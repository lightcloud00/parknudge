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

    var didOfferFirstCompletionPaywall: Bool {
        get { defaults.bool(forKey: Keys.didOfferFirstCompletionPaywall) }
        set { defaults.set(newValue, forKey: Keys.didOfferFirstCompletionPaywall) }
    }

    /// Marketing version the rating prompt was last *attempted* for. Attempted,
    /// not shown — StoreKit never reports whether it displayed anything.
    var lastReviewRequestVersion: String? {
        get { defaults.string(forKey: Keys.lastReviewRequestVersion) }
        set { defaults.set(newValue, forKey: Keys.lastReviewRequestVersion) }
    }

    private enum Keys {
        static let customReminderOffsets = "customReminderOffsets"
        static let currencyCode = "currencyCode"
        static let didOfferFirstCompletionPaywall = "didOfferFirstCompletionPaywall"
        static let lastReviewRequestVersion = "lastReviewRequestVersion"
    }
}
