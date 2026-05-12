import SwiftUI

struct HealthSyncScreen: View {
    @Bindable var state: OnboardingState

    var body: some View {
        OnboardingCard(
            title: "Connect Apple Health?",
            subtitle: "We'll read steps and active energy to fine-tune your daily calorie target. You can change this any time.",
            progress: state.progress,
            canAdvance: state.canAdvance,
            onBack: { withAnimation(Theme.Motion.spring) { state.goBack() } },
            onContinue: {
                Task { await state.commit() }
                withAnimation(Theme.Motion.spring) { state.advance() }
            }
        ) {
            VStack(spacing: Theme.Spacing.md) {
                heroIllustration

                OptionCard(
                    title: "Connect Apple Health",
                    subtitle: "Recommended",
                    systemImage: "heart.fill",
                    isSelected: state.healthSyncEnabled
                ) {
                    // Actual permission request lives in Phase 1.5 — for now just record intent.
                    state.healthSyncEnabled = true
                }

                OptionCard(
                    title: "Skip for now",
                    systemImage: "forward.fill",
                    isSelected: !state.healthSyncEnabled
                ) {
                    state.healthSyncEnabled = false
                }
            }
        }
    }

    private var heroIllustration: some View {
        Image(systemName: "heart.text.square.fill")
            .font(.system(size: 64))
            .foregroundStyle(Theme.Gradients.accent)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.md)
            .frame(maxWidth: .infinity)
    }
}
