import SwiftUI

struct PrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tapMedium()
            action()
        } label: {
            Text(title)
                .font(Theme.Type.bodyBold)
                .foregroundStyle(Theme.Palette.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Group {
                        if isEnabled {
                            Theme.Gradients.accent
                        } else {
                            Theme.Palette.surface
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radii.lg, style: .continuous))
                .opacity(isEnabled ? 1 : 0.6)
        }
        .disabled(!isEnabled)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tapLight()
            action()
        } label: {
            Text(title)
                .font(Theme.Type.bodyBold)
                .foregroundStyle(Theme.Palette.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radii.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radii.lg, style: .continuous)
                        .stroke(Theme.Palette.border, lineWidth: 1)
                )
        }
    }
}
