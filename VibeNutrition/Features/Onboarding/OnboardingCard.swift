import SwiftUI

/// Shared shell for every onboarding screen.
///
/// Layout contract (every screen looks structurally identical):
/// - Top bar: back chevron (or placeholder) + progress bar.
/// - Title block: `Theme.Typo.h2` headline + one-line subtitle slot.
/// - Content area: fills the remaining vertical space; rows inside use
///   `Onboarding.rowHeight` and `Onboarding.rowGap`.
/// - Continue button pinned to the bottom.
///
/// Horizontal inset for the content area is 4 pt so option rows extend
/// near edge-to-edge, while the 2 pt selection stroke still sits inside the
/// screen.
struct OnboardingCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    let progress: Double
    let canAdvance: Bool
    let onBack: (() -> Void)?
    let onContinue: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.sm)

                titleBlock
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.lg)

                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .padding(.top, Theme.Spacing.lg)

                PrimaryButton(title: "Continue", isEnabled: canAdvance, action: onContinue)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.lg)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: Theme.Spacing.md) {
            Group {
                if let onBack {
                    Button {
                        Haptics.tapLight()
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.Palette.textMuted)
                            .frame(width: 36, height: 36)
                            .background(Theme.Palette.surface, in: Circle())
                    }
                    .accessibilityLabel("Back")
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }
            }

            OnboardingProgressBar(progress: progress)
                .accessibilityLabel("Onboarding progress")
                .accessibilityValue("\(Int(progress * 100)) percent")

            Color.clear.frame(width: 36, height: 36)
        }
    }

    /// Two-row title block. The subtitle slot is always rendered (with an
    /// invisible placeholder when absent) so the content area starts at the
    /// same Y position whether or not the screen supplies a subtitle.
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(Theme.Typo.h2)
                .foregroundStyle(Theme.Palette.text)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle ?? " ")
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.textMuted)
                // Allow a second line for the few subtitles that don't fit in
                // 345pt on a 393pt device. fixedSize lets the block grow vertically
                // instead of truncating with an ellipsis.
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(subtitle == nil ? 0 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Layout constants shared across every onboarding screen so rows on
/// option, stepper, and slider screens all feel the same size.
enum Onboarding {
    /// Height of a single answer row (option card, stepper container, slider
    /// container). 60 pt is the magic number that lets a 6-row screen
    /// (Goal, Dietary) fit on a 393 × 852 pt iPhone without scrolling.
    static let rowHeight: CGFloat = 60
    /// Vertical gap between answer rows.
    static let rowGap: CGFloat = Theme.Spacing.sm
}

/// Standard slide transition between onboarding steps.
struct StepTransition: ViewModifier {
    func body(content: Content) -> some View {
        content
            .transition(
                .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                )
            )
    }
}

extension View {
    func stepTransition() -> some View { modifier(StepTransition()) }
}

#Preview {
    OnboardingCard(
        title: "What's your main goal?",
        subtitle: "We'll tune your calories and macros to match.",
        progress: 0.15,
        canAdvance: true,
        onBack: {},
        onContinue: {}
    ) {
        VStack(spacing: Onboarding.rowGap) {
            OptionCard(title: "Lose weight", systemImage: "flame.fill", tint: .orange, isSelected: true) {}
            OptionCard(title: "Gain weight", systemImage: "chart.line.uptrend.xyaxis", tint: .green, isSelected: false) {}
        }
    }
    .preferredColorScheme(.dark)
}
