import SwiftUI

/// Pip the Pin, drawn from the vector image sets in `Assets.xcassets/Mascot`.
///
/// Decorative everywhere it appears: hidden from VoiceOver, and removed at
/// the accessibility text sizes, where the room belongs to the words. A mood
/// change swaps the art once; Pip never loops, and under Reduce Motion the
/// swap is instant.
struct PipView: View {
    let mood: PipMood
    var size: CGFloat = 120

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !dynamicTypeSize.isAccessibilitySize {
            ZStack {
                Image(mood.assetName)
                    .resizable()
                    .scaledToFit()
                    .id(mood)
                    .transition(
                        reduceMotion ? .identity : .scale(scale: 0.85).combined(with: .opacity)
                    )
            }
            .frame(width: size, height: size)
            .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.3), value: mood)
            .accessibilityHidden(true)
        }
    }
}
