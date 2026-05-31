import SwiftUI

/// Self-contained palette mirroring the app's `Theme.Palette`, kept local to the
/// widget so it doesn't pull in the app's UIKit-flavored Theme file.
enum WColor {
    static let bg = Color(light: 0xF6F7FB, dark: 0x0A0A0F)
    static let surface = Color(light: 0xFFFFFF, dark: 0x1A1A26)
    static let text = Color(light: 0x0A0A12, dark: 0xF5F5FA)
    static let textMuted = Color(light: 0x5A6072, dark: 0x9AA0B0)
    static let accent = Color(light: 0x0EA5E9, dark: 0x22D3EE)
    static let accentAlt = Color(light: 0x10B981, dark: 0x34D399)
    static let accentDeep = Color(light: 0x0284C7, dark: 0x0EA5E9)
    static let warning = Color(light: 0xD97706, dark: 0xFBBF24)
    static let track = Color(light: 0xDFE2EA, dark: 0x2A2A38)

    static let accentGradient = LinearGradient(
        colors: [accent, accentAlt], startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

private extension Color {
    init(light: UInt32, dark: UInt32) {
        self = Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .light ? light : dark
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}
