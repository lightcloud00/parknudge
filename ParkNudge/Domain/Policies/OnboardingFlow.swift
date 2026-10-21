import Foundation

/// The first-launch introduction (Figma page 27:2, screens 1–6).
enum OnboardingStep: String, CaseIterable, Sendable {
    case promise
    case parkingStyle
    case location
    case firstSave
    case reminders
    case pro

    /// Pip's state on each screen, from the page's Mascot Slot hints.
    var pipMood: PipMood {
        switch self {
        case .promise, .parkingStyle: .idle
        case .location: .nudge
        case .firstSave: .sleepy
        case .reminders: .alarm
        case .pro: .happy
        }
    }

    /// Skip ends the introduction from any screen that is not itself a
    /// permission explanation. Those offer only Continue, so iOS's own prompt
    /// is always the place where access is granted or declined.
    var offersSkip: Bool {
        switch self {
        case .promise, .parkingStyle, .firstSave: true
        case .location, .reminders, .pro: false
        }
    }
}

enum OnboardingFlow {
    /// Shown once to someone who has never parked with ParkNudge. Anyone who
    /// already has a saved or finished session — for example after updating
    /// from a version without onboarding — is treated as having seen it.
    static func shouldPresent(hasCompleted: Bool, hasParkingHistory: Bool) -> Bool {
        !hasCompleted && !hasParkingHistory
    }

    /// The screen after `step`, or `nil` when the introduction is finished.
    ///
    /// - Parameters:
    ///   - hasActiveSession: A spot is already saved, as on a replay from
    ///     Settings. The location, first-save, and reminder screens exist to
    ///     reach that first save, so they are passed over.
    ///   - remindersAwaitPermission: The first save set a meter whose
    ///     reminders could not be scheduled yet because notifications have
    ///     not been allowed. Without a meter there is nothing to remind about.
    static func step(
        after step: OnboardingStep,
        hasActiveSession: Bool,
        remindersAwaitPermission: Bool
    ) -> OnboardingStep? {
        switch step {
        case .promise: .parkingStyle
        case .parkingStyle: hasActiveSession ? .pro : .location
        case .location: .firstSave
        case .firstSave: remindersAwaitPermission ? .reminders : .pro
        case .reminders: .pro
        case .pro: nil
        }
    }

    /// "15 and 5 minutes before, then when it ends", built from the offsets a
    /// save would actually schedule so the copy cannot drift from them.
    static func reminderSummary(offsets: [Int]) -> String {
        let before = ReminderPlanner.normalizedOffsets(offsets).filter { $0 > 0 }
        let endsToo = offsets.contains(0)
        let lead: String
        switch before.count {
        case 0:
            return endsToo ? "when it ends" : ""
        case 1:
            lead = "\(before[0]) minutes before"
        default:
            lead = before.dropLast().map(String.init).joined(separator: ", ")
                + " and \(before[before.count - 1]) minutes before"
        }
        return endsToo ? lead + ", then when it ends" : lead
    }
}
