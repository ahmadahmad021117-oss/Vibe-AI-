import SwiftUI

#Preview {
    MealSuggestionsScreen(state: OnboardingState())
        .preferredColorScheme(.dark)
}

struct MealSuggestionsScreen: View {
    @Bindable var state: OnboardingState

    var body: some View {
        OnboardingCard(
            title: "Get meal ideas after each scan?",
            subtitle: "We'll suggest what to eat next based on your remaining macros.",
            progress: state.progress,
            canAdvance: state.canAdvance,
            onBack: { withAnimation(Theme.Motion.spring) { state.goBack() } },
            onContinue: {
                Task { await state.commit() }
                withAnimation(Theme.Motion.spring) { state.advance() }
            }
        ) {
            VStack(spacing: Theme.Spacing.md) {
                OptionCard(
                    title: "Yes, suggest meals",
                    systemImage: "sparkles",
                    isSelected: state.mealSuggestionsEnabled
                ) {
                    state.mealSuggestionsEnabled = true
                }
                OptionCard(
                    title: "No thanks",
                    systemImage: "xmark.circle",
                    isSelected: !state.mealSuggestionsEnabled
                ) {
                    state.mealSuggestionsEnabled = false
                }
            }
        }
    }
}
