import Foundation

/// Everything the app knows when it considers asking for a rating.
struct ReviewPromptContext: Equatable, Sendable {
    /// Sessions the user has actually finished — the only evidence of value
    /// delivered that this app has.
    var completedSessionCount: Int
    /// Marketing version the prompt was last attempted for, if ever.
    var lastRequestedVersion: String?
    var lastRequestedDate: Date?
    var currentVersion: String
    var now: Date
    /// An alert is on screen.
    var hasActiveAlert: Bool
    var hasActiveConfirmation: Bool
    var isPaywallPresented: Bool
    var isPurchasePresented: Bool
    var isBusy: Bool
    var isOnboardingPresented: Bool
    var isLaunchInProgress: Bool
}

/// Decides whether this is a decent moment to ask for an App Store rating.
///
/// The rule the product actually wants is "after repeated success, never during
/// pressure". Encoding it here — rather than inline at the call site — is what
/// makes it testable, and what keeps the several negative conditions from
/// quietly drifting apart.
enum ReviewPromptPolicy {
    /// The third finished session. One is a trial, two is a coincidence.
    static let minimumCompletedSessions = 3
    static let cooldown: TimeInterval = 120 * 24 * 60 * 60

    static func shouldRequest(_ context: ReviewPromptContext) -> Bool {
        guard context.completedSessionCount >= minimumCompletedSessions else { return false }
        guard !context.currentVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        // At most one attempt per marketing version. Apple rate-limits this
        // independently; that is not a licence to ask on every launch.
        guard context.lastRequestedVersion != context.currentVersion else { return false }
        if let lastRequestedDate = context.lastRequestedDate,
           context.now.timeIntervalSince(lastRequestedDate) < cooldown
        {
            return false
        }

        // Never on top of pressure or failure: an error the user is reading, a
        // paywall asking for money, or work still in flight.
        guard !context.hasActiveAlert,
              !context.hasActiveConfirmation,
              !context.isPaywallPresented,
              !context.isPurchasePresented,
              !context.isBusy,
              !context.isOnboardingPresented,
              !context.isLaunchInProgress
        else {
            return false
        }

        return true
    }
}
