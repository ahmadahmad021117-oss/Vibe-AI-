import SwiftUI

#Preview {
    DietaryPrefScreen(state: OnboardingState())
        .preferredColorScheme(.dark)
}

struct DietaryPrefScreen: View {
    @Bindable var state: OnboardingState

    private let icons: [DietaryPref: String] = [
        .normal: "fork.knife",
        .highProtein: "bolt.fill",
        .vegetarian: "leaf.fill",
        .vegan: "leaf.circle.fill",
        .halal: "moon.stars.fill",
        .keto: "drop.fill",
    ]

    var body: some View {
        OnboardingCard(
            title: "Any dietary preferences?",
            subtitle: "We'll bias meal suggestions to fit.",
            progress: state.progress,
            canAdvance: state.canAdvance,
            onBack: { withAnimation(Theme.Motion.spring) { state.goBack() } },
            onContinue: {
                Task { await state.commit() }
                withAnimation(Theme.Motion.spring) { state.advance() }
            }
        ) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(DietaryPref.allCases) { pref in
                        OptionCard(
                            title: pref.label,
                            systemImage: icons[pref],
                            isSelected: state.dietaryPref == pref
                        ) {
                            state.dietaryPref = pref
                        }
                    }
                }
            }
        }
    }
}
