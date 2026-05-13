import SwiftUI

struct OptionCard: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? Theme.Palette.accent : Theme.Palette.textMuted)
                        .frame(width: 32)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Type.bodyBold)
                        .foregroundStyle(Theme.Palette.text)
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.Type.caption)
                            .foregroundStyle(Theme.Palette.textMuted)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.Palette.accent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radii.lg, style: .continuous)
                    .fill(isSelected ? Theme.Palette.surfaceHi : Theme.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radii.lg, style: .continuous)
                    .stroke(
                        isSelected ? Theme.Palette.accent : Theme.Palette.border,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .animation(Theme.Motion.spring, value: isSelected)
        .accessibilityLabel(title)
        .accessibilityValue(subtitle ?? "")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

#Preview {
    VStack(spacing: 12) {
        OptionCard(title: "Lose weight",
                   subtitle: "Drop body fat steadily",
                   systemImage: "arrow.down.right",
                   isSelected: true) {}
        OptionCard(title: "Maintain weight",
                   systemImage: "equal.circle",
                   isSelected: false) {}
    }
    .padding()
    .background(Theme.Palette.bg)
    .preferredColorScheme(.dark)
}
