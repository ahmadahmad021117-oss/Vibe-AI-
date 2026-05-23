import SwiftUI

struct OptionCard: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    /// When provided, the icon renders inside a colored squircle (iOS
    /// Settings-style "icon chip") rather than the muted line-icon look. Each
    /// option on a question screen gets a distinct hue so the row reads as a
    /// recognisable shape at a glance, not a generic monochrome bullet.
    var tint: Color? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                if let systemImage {
                    iconView(systemImage: systemImage)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Typo.bodyBold)
                        .foregroundStyle(Theme.Palette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    if let subtitle {
                        // lineLimit(1) + scale-down keeps "About 0.75 kg /
                        // week" on a single row even when the checkmark badge
                        // takes the trailing column. Without it the subtitle
                        // wrapped to 2 lines and the card height jumped.
                        Text(subtitle)
                            .font(Theme.Typo.caption)
                            .foregroundStyle(Theme.Palette.textMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: Theme.Spacing.xs)
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
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            // Soft accent glow on selection so the card feels alive instead
            // of just changing border colour.
            .shadow(color: isSelected ? Theme.Palette.accent.opacity(0.35) : .clear,
                    radius: isSelected ? 14 : 0)
            .scaleEffect(isSelected ? 1.02 : 1)
        }
        .animation(Theme.Motion.spring, value: isSelected)
        .accessibilityLabel(title)
        .accessibilityValue(subtitle ?? "")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    @ViewBuilder
    private func iconView(systemImage: String) -> some View {
        if let tint {
            // Tinted squircle badge — gradient fill (slightly darker corner)
            // adds depth so the chip doesn't read as a flat sticker. Selection
            // ring matches the chip's own tint, then `OptionCard`'s outer
            // stroke takes over once selected.
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)
            .shadow(color: tint.opacity(isSelected ? 0.55 : 0.25),
                    radius: isSelected ? 8 : 4, x: 0, y: 2)
            .scaleEffect(isSelected ? 1.05 : 1)
        } else {
            // Untinted fallback (preserves the original look for any caller
            // that hasn't migrated to the new tint API yet).
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.Palette.accent : Theme.Palette.textMuted)
                .frame(width: 32)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        OptionCard(title: "Lose weight",
                   subtitle: "Drop body fat steadily",
                   systemImage: "flame.fill",
                   tint: .orange,
                   isSelected: true) {}
        OptionCard(title: "Build muscle",
                   subtitle: "Strength + size",
                   systemImage: "dumbbell.fill",
                   tint: .blue,
                   isSelected: false) {}
        OptionCard(title: "Maintain weight",
                   systemImage: "equal.square.fill",
                   tint: .teal,
                   isSelected: false) {}
    }
    .padding()
    .background(Theme.Palette.bg)
    .preferredColorScheme(.dark)
}
