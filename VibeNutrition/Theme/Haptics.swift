import UIKit

enum Haptics {
    static func tapLight() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func tapMedium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func tapHeavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    static func select() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func warn() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
