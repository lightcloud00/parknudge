import SwiftUI

enum UITestAppearance {
    /// `-AppleInterfaceStyle` is not reliably applied to app launches by the
    /// iOS 26 simulator. Mirror the requested style inside the DEBUG app so a
    /// capture named "dark" cannot silently render in light appearance.
    static func colorScheme(arguments: [String]) -> ColorScheme? {
        #if DEBUG
        guard arguments.contains("-ui-testing") else { return nil }
        let values = arguments.enumerated().compactMap { index, argument -> String? in
            guard argument == "-AppleInterfaceStyle", arguments.indices.contains(index + 1) else {
                return nil
            }
            return arguments[index + 1]
        }
        guard values.count == 1 else { return nil }
        switch values[0].lowercased() {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
        #else
        return nil
        #endif
    }
}
