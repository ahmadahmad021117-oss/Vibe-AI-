import SwiftUI

/// Two-option screen — matches the visual family of the other onboarding
/// screens (no hero illustration, just the two rows).
struct HealthSyncScreen: View {
    @Bindable var state: OnboardingState

    var body: some View {
        OnboardingCard(
            title: "Connect Apple Health?",
            subtitle: "Steps and activity fine-tune your calorie target.",
            progress: state.progress,
            canAdvance: state.canAdvance,
            onBack: { withAnimation(Theme.Motion.spring) { state.goBack() } },
            onContinue: {
                Task { await state.commit() }
                withAnimation(Theme.Motion.spring) { state.advance() }
            }
        ) {
            VStack(spacing: Onboarding.rowGap) {
                OptionCard(
                    title: "Connect Apple Health",
                    subtitle: "Recommended",
                    systemImage: "heart.fill",
                    tint: .pink,
                    isSelected: state.healthSyncEnabled
                ) {
                    state.healthSyncEnabled = true
                    Task {
                        // Surface the system permission sheet immediately. A
                        // denial is treated as "intent recorded" — the plan
                        // generator just skips the activity step.
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
}

#Preview {
    HealthSyncScreen(state: OnboardingState())
        .preferredColorScheme(.dark)
}
