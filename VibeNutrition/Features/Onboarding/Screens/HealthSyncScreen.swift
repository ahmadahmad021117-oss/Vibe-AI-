import SwiftUI

#Preview {
    HealthSyncScreen(state: OnboardingState())
        .preferredColorScheme(.dark)
}

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
                    tint: .pink,
                    isSelected: state.healthSyncEnabled
                ) {
                    state.healthSyncEnabled = true
                    Task {
                        // Surface the system permission sheet immediately. The user can deny;
                        // we treat that as "intent recorded, no actual data flow" and the plan
                        // generator will just skip the step.
                        try? await HealthKitService.shared.requestAuthorization()
                    }
                }

                OptionCard(
                    title: "Skip for now",
                    systemImage: "forward.fill",
                    tint: .gray,
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
