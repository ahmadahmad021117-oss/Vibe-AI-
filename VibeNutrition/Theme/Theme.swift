import SwiftUI

enum Theme {
    /// All palette colors are dynamic: they resolve to the `light` hex when the
    /// active interface style is light and the `dark` hex otherwise. Because the
    /// resolution happens inside the trait collection, every existing
    /// `Theme.Palette.*` reference adapts automatically — no call sites change.
    enum Palette {
        static let bg = Color(light: 0xF6F7FB, dark: 0x0A0A0F)
        static let bgElevated = Color(light: 0xFFFFFF, dark: 0x13131C)
        static let surface = Color(light: 0xFFFFFF, dark: 0x1A1A26)
        static let surfaceHi = Color(light: 0xEEF0F6, dark: 0x22222F)
        static let border = Color(light: 0xDFE2EA, dark: 0x2A2A38)
        static let text = Color(light: 0x0A0A12, dark: 0xF5F5FA)
        static let textMuted = Color(light: 0x5A6072, dark: 0x9AA0B0)
        static let textDim = Color(light: 0x9298A6, dark: 0x6B7080)
        static let accent = Color(light: 0x0EA5E9, dark: 0x22D3EE)
        static let accentAlt = Color(light: 0x10B981, dark: 0x34D399)
        static let accentDeep = Color(light: 0x0284C7, dark: 0x0EA5E9)
        static let danger = Color(light: 0xDC2626, dark: 0xF87171)
        static let warning = Color(light: 0xD97706, dark: 0xFBBF24)
        static let success = Color(light: 0x059669, dark: 0x34D399)
    }

    enum Gradients {
        static let accent = LinearGradient(
            colors: [Palette.accent, Palette.accentAlt],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        static let hero = LinearGradient(
            colors: [Palette.accentDeep, Palette.accent, Palette.accentAlt],
            startPoint: .top, endPoint: .bottom
        )
        static let surface = LinearGradient(
            colors: [Palette.bgElevated, Palette.bg],
            startPoint: .top, endPoint: .bottom
        )
    }

    enum Radii {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
        static let pill: CGFloat = 999
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Motion {
        static let fast: Double = 0.18
        static let base: Double = 0.25
        static let slow: Double = 0.35
        static let spring = Animation.interpolatingSpring(stiffness: 220, damping: 22)
    }

    /// Typography (renamed from `Type` — Swift 6 forbids nested types named `Type`
    /// because it collides with the metatype expression syntax).
    enum Typo {
        static let h1 = Font.system(size: 32, weight: .bold, design: .rounded)
        static let h2 = Font.system(size: 24, weight: .bold, design: .rounded)
        static let h3 = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 16, weight: .regular)
        static let bodyBold = Font.system(size: 16, weight: .semibold)
        static let caption = Font.system(size: 13, weight: .regular)
        static let numeralXL = Font.system(size: 56, weight: .heavy, design: .rounded)
        static let numeralLG = Font.system(size: 40, weight: .bold, design: .rounded)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    /// A color that resolves per interface style. The closure runs against the
    /// rendering view's trait collection, so it tracks `.preferredColorScheme`
    /// and live system light/dark changes without any observation wiring.
    init(light: UInt32, dark: UInt32, alpha: Double = 1) {
        self = Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .light ? light : dark
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: CGFloat(alpha)
            )
        })
    }
}

/// Number formatting helpers locked to en_US so the grouping separator is a
/// comma, matching the English-only copy. SwiftUI's `Text("\(intValue)")`
/// otherwise uses the device locale and shows "4 026" on EU phones — confusing
/// next to English labels like "kcal left".
extension Int {
    var grouped: String { formatted(.number.locale(Locale(identifier: "en_US"))) }
}

extension Double {
    /// Always show `digits` fractional digits, with US grouping. Use this on
    /// any number rendered next to English unit copy (g, mg, µg, kcal, kg).
    func grouped(_ digits: Int) -> String {
        formatted(
            .number
                .locale(Locale(identifier: "en_US"))
                .precision(.fractionLength(digits))
        )
    }
}
