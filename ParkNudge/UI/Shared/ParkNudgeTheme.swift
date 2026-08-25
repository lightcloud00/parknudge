import SwiftUI

/// Semantic design tokens for ParkNudge.
///
/// Every colour here is sampled from, or derived from, the shipped 1024×1024
/// app icon: the navy ground `#031738`, and the pin's amber-to-orange ramp
/// `#FDAE11` → `#EE6605`. Before this existed the views hardcoded `.orange`
/// and four different corner radii (22 / 20 / 16 / 14), and `AccentColor` in
/// the asset catalogue was a leftover blue that no view ever matched.
enum Theme {
    // MARK: - Identity

    /// The fill that sits **under white text** — `.borderedProminent` tints,
    /// filled glyph tiles, the map marker. Deliberately the same value in both
    /// appearances: a lighter dark-mode variant put white on it at 1.87:1.
    /// White on this is 3.21:1, above the 3:1 non-text and large-control floor.
    /// Never use it for text.
    static let brand = Color("BrandOrange", bundle: .main)

    /// Orange **text and labels**. 5.57:1 on white, 4.86:1 on a grouped-list
    /// fill, 11.2:1 on black — so it clears the 4.5:1 body-text floor in both
    /// appearances, which `brand` does not.
    static let brandInk = Color("BrandInk", bundle: .main)

    /// Destructive text. The system red fails on a `.bordered` button's fill
    /// (3.09:1); this reaches 5.70:1 light and 4.99:1 dark.
    static let alertInk = Color("MeterAlertInk", bundle: .main)

    /// The icon's navy, used as the calm meter surface.
    static let navy = Color("BrandNavy", bundle: .main)

    /// On-navy foreground.
    static let cream = Color("BrandCream", bundle: .main)

    // MARK: - Surfaces

    static let surface = Color(uiColor: .systemBackground)
    static let surfaceRaised = Color(uiColor: .secondarySystemBackground)
    static let separator = Color(uiColor: .separator)

    // MARK: - Radii

    /// Cards, the map, and the meter hero.
    static let radiusCard: CGFloat = 20
    /// Photos and inline tiles.
    static let radiusTile: CGFloat = 14
    /// Chips and list thumbnails.
    static let radiusInline: CGFloat = 8

    // MARK: - Metrics

    /// Apple's minimum comfortable hit target.
    static let minimumHitTarget: CGFloat = 44
    static let primaryControlHeight: CGFloat = 50
}

extension MeterState {
    /// Tile background for this state.
    var surface: Color {
        switch self {
        case .running: Theme.navy
        case .expiringSoon: Color("MeterWarnSurface", bundle: .main)
        case .expired: Color("MeterAlertSurface", bundle: .main)
        }
    }

    /// The countdown's own colour.
    var accent: Color {
        switch self {
        case .running: .white
        case .expiringSoon: Color("MeterWarnInk", bundle: .main)
        case .expired: Color("MeterAlertInk", bundle: .main)
        }
    }

    /// Label and secondary text on `surface`.
    var secondaryAccent: Color {
        switch self {
        case .running: Theme.cream.opacity(0.75)
        case .expiringSoon: Color("MeterWarnInk", bundle: .main).opacity(0.85)
        case .expired: Color("MeterAlertInk", bundle: .main).opacity(0.85)
        }
    }

    /// SF Symbol, chosen so the three states stay distinguishable without
    /// colour — the icons differ in shape and weight, not only in hue.
    var symbol: String {
        switch self {
        case .running: "timer"
        case .expiringSoon: "exclamationmark.circle.fill"
        case .expired: "exclamationmark.triangle.fill"
        }
    }

    /// Weight of the countdown. Urgency reads through weight as well as colour.
    var digitWeight: Font.Weight {
        switch self {
        case .running: .semibold
        case .expiringSoon, .expired: .bold
        }
    }
}
