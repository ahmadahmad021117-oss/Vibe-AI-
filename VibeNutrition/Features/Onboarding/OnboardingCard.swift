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

            VStack(spacing: Theme.Spacing.lg) {
                topBar

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(title)
                        .font(Theme.Typo.h1)
                        .foregroundStyle(Theme.Palette.text)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.Typo.body)
                            .foregroundStyle(Theme.Palette.textMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.lg)

                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, Theme.Spacing.lg)

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
