import Foundation

/// Parses meter-state seed arguments used only by the in-memory UI-test environment.
enum UITestMeterSeed {
    static let argumentPrefix = "-ui-test-meter-offset="
    static let defaultOffset: TimeInterval = 3_600
    static let maximumMagnitude: TimeInterval = 7 * 24 * 60 * 60

    static func offset(arguments: [String]) throws -> TimeInterval? {
        let values = arguments.compactMap { argument -> String? in
            guard argument.hasPrefix(argumentPrefix) else { return nil }
            return String(argument.dropFirst(argumentPrefix.count))
        }
        guard values.count <= 1 else { throw SeedError.duplicateOffset }

        if let value = values.first {
            guard let offset = TimeInterval(value), offset.isFinite,
                  abs(offset) <= maximumMagnitude
            else {
                throw SeedError.invalidOffset(value)
            }
            return offset
        }

        return arguments.contains("-ui-test-active-meter") ? defaultOffset : nil
    }

    enum SeedError: Error, Equatable {
        case duplicateOffset
        case invalidOffset(String)
    }
}
