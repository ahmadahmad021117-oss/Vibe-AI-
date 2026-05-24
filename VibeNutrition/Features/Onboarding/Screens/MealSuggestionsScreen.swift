import SwiftUI

struct MealSuggestionsScreen: View {
    @Bindable var state: OnboardingState

    var body: some View {
        OnboardingCard(
            title: "Get meal ideas after each scan?",
            subtitle: "We'll suggest what to eat next based on remaining macros.",
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
                    title: "Yes, suggest meals",
                    systemImage: "sparkles",
                    tint: Theme.Palette.accent,
                    isSelected: state.mealSuggestionsEnabled
                ) {
                    state.mealSuggestionsEnabled = true
                }
                OptionCard(
                    title: "No thanks",
                    systemImage: "xmark",
                    tint: .gray,
                    isSelected: !state.mealSuggestionsEnabled
                ) {
                    state.mealSuggestionsEnabled = false
                }
            }
        }
    }
}

#Preview {
    MealSuggestionsScreen(state: OnboardingState())
        .preferredColorScheme(.dark)
}
