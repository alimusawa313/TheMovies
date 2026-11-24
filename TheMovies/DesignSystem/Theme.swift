import SwiftUI
import UIKit

/// Design tokens: colours, spacing, radii. Every colour adapts to light and
/// dark appearance.
enum Theme {
    static let background = Color(
        light: Color(red: 0.965, green: 0.958, blue: 0.975),
        dark: Color(red: 0.035, green: 0.035, blue: 0.06)
    )
    static let surface = Color(light: .black.opacity(0.05), dark: .white.opacity(0.06))
    static let surfaceRaised = Color(light: .white, dark: .white.opacity(0.1))
    static let stroke = Color(light: .black.opacity(0.08), dark: .white.opacity(0.1))
    static let shimmerHighlight = Color(light: .white.opacity(0.75), dark: .white.opacity(0.16))
    static let track = Color(light: .black.opacity(0.08), dark: .white.opacity(0.1))
    static let shadow = Color(light: .black.opacity(0.12), dark: .black.opacity(0.45))

    static let accent = Color(
        light: Color(red: 0.9, green: 0.22, blue: 0.33),
        dark: Color(red: 1.0, green: 0.36, blue: 0.42)
    )
    static let accentWarm = Color(
        light: Color(red: 0.96, green: 0.5, blue: 0.12),
        dark: Color(red: 1.0, green: 0.64, blue: 0.27)
    )

    static let textPrimary = Color.primary
    static let textSecondary = Color(light: .black.opacity(0.62), dark: .white.opacity(0.68))
    static let textTertiary = Color(light: .black.opacity(0.4), dark: .white.opacity(0.42))

    static let accentGradient = LinearGradient(
        colors: [accent, accentWarm],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Fade from transparent to the page background, used under hero images.
    static let scrim = LinearGradient(
        stops: [
            .init(color: background.opacity(0), location: 0),
            .init(color: background.opacity(0.6), location: 0.55),
            .init(color: background, location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Green → amber → red according to a 0...1 score.
    static func ratingColor(_ fraction: Double) -> Color {
        switch fraction {
        case 0.7...:
            Color(light: Color(red: 0.12, green: 0.62, blue: 0.36), dark: Color(red: 0.3, green: 0.85, blue: 0.55))
        case 0.5..<0.7:
            Color(light: Color(red: 0.85, green: 0.55, blue: 0.0), dark: Color(red: 1.0, green: 0.78, blue: 0.3))
        default:
            Color(light: Color(red: 0.85, green: 0.2, blue: 0.2), dark: Color(red: 1.0, green: 0.42, blue: 0.42))
        }
    }

    nonisolated enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    nonisolated enum Radius {
        static let s: CGFloat = 10
        static let m: CGFloat = 16
        static let l: CGFloat = 24
    }
}

extension Color {
    /// A colour that resolves differently in light and dark appearance.
    ///
    /// `nonisolated` + `@Sendable`: SwiftUI resolves dynamic colours on its
    /// render thread, so the provider must not be main-actor isolated.
    nonisolated init(light: Color, dark: Color) {
        let lightColor = UIColor(light)
        let darkColor = UIColor(dark)
        self.init(uiColor: UIColor { @Sendable traits in
            traits.userInterfaceStyle == .dark ? darkColor : lightColor
        })
    }
}

/// User-selectable appearance, persisted with `@AppStorage`.
enum AppearancePreference: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appearance.preference"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Shared animation curves so motion feels consistent across the app.
enum Motion {
    static let bouncy = Animation.spring(response: 0.48, dampingFraction: 0.66)
    static let snappy = Animation.snappy(duration: 0.28)
    static let smooth = Animation.smooth(duration: 0.45)
    static let gentle = Animation.spring(response: 0.7, dampingFraction: 0.85)

    private static let staggerStep = 0.045
    private static let staggerLimit = 12

    /// Delay for list entrance animations; only the first screenful is staggered.
    static func staggerDelay(for index: Int) -> Double {
        index < staggerLimit ? Double(index) * staggerStep : 0
    }
}
