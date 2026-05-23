import SwiftUI

#Preview {
    DietaryPrefScreen(state: OnboardingState())
        .preferredColorScheme(.dark)
}

struct DietaryPrefScreen: View {
    @Bindable var state: OnboardingState

    // Carrot for vegan (was a second leaf) — much easier to tell apart from
    // vegetarian. Keto reads as fire (fat oxidation) rather than the generic
    // water-drop it used to use.
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
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.sm) {
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
}
