import SwiftUI

/// Reusable full-screen onboarding card.
/// One question per screen; the question is the headline, the answer UI fills the body.
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

            // Tighter outer spacing (md vs lg) so 6-option questions like
            // Goal / Dietary fit on one screen.
            VStack(spacing: Theme.Spacing.md) {
                topBar

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(Theme.Typo.h2)
                        .foregroundStyle(Theme.Palette.text)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.Typo.body)
                            .foregroundStyle(Theme.Palette.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.lg)

                // 4pt horizontal inset — the cards extend to the screen
                // edges (matching the MainFocus look the user signed off on),
                // and since the outer accent glow is now removed, nothing
                // bleeds past the screen anymore.
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, Theme.Spacing.xs)

                PrimaryButton(title: "Continue", isEnabled: canAdvance) {
                    onContinue()
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.lg)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: Theme.Spacing.md) {
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
            OnboardingProgressBar(progress: progress)
                .accessibilityLabel("Onboarding progress")
                .accessibilityValue("\(Int(progress * 100)) percent")
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.sm)
    }
}

/// Wrap a step view with the standard slide transition.
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
        title: "What's your goal?",
        subtitle: "Pick the one that fits best — we'll tune from there.",
        progress: 0.15,
        canAdvance: true,
        onBack: {},
        onContinue: {}
    ) {
        VStack(spacing: 12) {
            OptionCard(title: "Lose weight", systemImage: "arrow.down.right", isSelected: true) {}
            OptionCard(title: "Build muscle", systemImage: "figure.strengthtraining.traditional", isSelected: false) {}
        }
    }
    .preferredColorScheme(.dark)
}
