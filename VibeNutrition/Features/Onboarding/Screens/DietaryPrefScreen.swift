import SwiftUI

struct DietaryPrefScreen: View {
    @Bindable var state: OnboardingState

    private let style: [DietaryPref: (String, Color)] = [
        .normal:      ("fork.knife",      .gray),
        .highProtein: ("bolt.fill",       .yellow),
        .vegetarian:  ("leaf.fill",       Color(red: 0.20, green: 0.78, blue: 0.40)),
        .vegan:       ("carrot.fill",     .orange),
        .halal:       ("moon.stars.fill", .indigo),
        .keto:        ("flame.fill",      .red),
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
            VStack(spacing: Onboarding.rowGap) {
                ForEach(DietaryPref.allCases) { pref in
                    let s = style[pref]
                    OptionCard(
                        title: pref.label,
                        systemImage: s?.0,
                        tint: s?.1,
                        isSelected: state.dietaryPref == pref
                    ) {
                        state.dietaryPref = pref
                    }
                }
            }
        }
    }
}

#Preview {
    DietaryPrefScreen(state: OnboardingState())
        .preferredColorScheme(.dark)
}
