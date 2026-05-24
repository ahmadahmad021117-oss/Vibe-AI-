import SwiftUI

/// A single answer row used across every onboarding screen.
///
/// Visual contract:
/// - Fixed height of `Onboarding.rowHeight` so every screen lines up.
/// - 36 × 36 tinted "icon chip" on the left (per-option SF Symbol + tint).
/// - Title (+ optional one-line subtitle) in the middle.
/// - Right side: checkmark when selected.
/// - Selection feedback is contained to the rounded rectangle: a 2 pt accent
///   stroke and the checkmark. No outer shadow / glow that bleeds past the
///   card.
struct OptionCard: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
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
                    iconChip(systemImage: systemImage)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(Theme.Typo.bodyBold)
                        .foregroundStyle(Theme.Palette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    if let subtitle {
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
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .frame(height: Onboarding.rowHeight)
            .frame(maxWidth: .infinity)
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
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radii.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(Theme.Motion.spring, value: isSelected)
        .accessibilityLabel(title)
        .accessibilityValue(subtitle ?? "")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    @ViewBuilder
    private func iconChip(systemImage: String) -> some View {
        let fill = tint ?? Theme.Palette.textMuted
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [fill, fill.opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 36, height: 36)
    }
}

#Preview {
    VStack(spacing: Onboarding.rowGap) {
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
