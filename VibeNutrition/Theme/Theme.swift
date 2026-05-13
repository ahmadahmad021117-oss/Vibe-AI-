import SwiftUI

enum Theme {
    enum Palette {
        static let bg = Color(hex: 0x0A0A0F)
        static let bgElevated = Color(hex: 0x13131C)
        static let surface = Color(hex: 0x1A1A26)
        static let surfaceHi = Color(hex: 0x22222F)
        static let border = Color(hex: 0x2A2A38)
        static let text = Color(hex: 0xF5F5FA)
        static let textMuted = Color(hex: 0x9AA0B0)
        static let textDim = Color(hex: 0x6B7080)
        static let accent = Color(hex: 0x22D3EE)
        static let accentAlt = Color(hex: 0x34D399)
        static let accentDeep = Color(hex: 0x0EA5E9)
        static let danger = Color(hex: 0xF87171)
        static let warning = Color(hex: 0xFBBF24)
        static let success = Color(hex: 0x34D399)
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
}
