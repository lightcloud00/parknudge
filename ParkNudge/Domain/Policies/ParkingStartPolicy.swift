import Foundation

/// New customers earn one real result before paying: one complete parking
/// session (save the spot, see the return route and reminder plan, finish).
/// Starting another session needs Lifetime Pro. Verified Pro and verified
/// original customers are never gated, and a saved session can always be
/// navigated to and finished.
enum ParkingStartPolicy {
    static let freeSessions = 1

    static func canStart(hasPaidParkingAccess: Bool, sessionsStarted: Int) -> Bool {
        hasPaidParkingAccess || sessionsStarted < freeSessions
    }

    /// Free sessions left for the visible meter; nil when paid access makes it moot.
    static func freeSessionsRemaining(hasPaidParkingAccess: Bool, sessionsStarted: Int) -> Int? {
        hasPaidParkingAccess ? nil : max(0, freeSessions - sessionsStarted)
    }
}
