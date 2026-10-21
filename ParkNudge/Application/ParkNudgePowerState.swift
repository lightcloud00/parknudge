import Foundation

enum ParkNudgePowerState {
    static func current(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        systemLowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled
    ) -> Bool {
        if arguments.contains("-ui-testing"), arguments.contains("-ui-test-low-power-mode") {
            return true
        }
        return systemLowPowerMode
    }
}
