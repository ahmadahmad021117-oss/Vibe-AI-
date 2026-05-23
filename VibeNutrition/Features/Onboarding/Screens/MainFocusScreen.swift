import SwiftUI

#Preview {
    MainFocusScreen(state: OnboardingState())
        .preferredColorScheme(.dark)
}

struct MainFocusScreen: View {
    @Bindable var state: OnboardingState

    // Tints intentionally mirror the GoalScreen palette so a "Gain weight"
    // user picking "Muscle gain" sees the same blue twice in a row — small
    // cue that the two questions reinforce each other rather than ask the
    // same thing.
    private let style: [MainFocus: (String, Color)] = [
        .fatLoss:       ("flame.fill",                  .orange),
        .muscleGain:    ("dumbbell.fill",               .blue),
        .recomp:        ("arrow.triangle.2.circlepath", .purple),
        .generalHealth: ("cross.case.fill",             Color(red: 0.20, green: 0.78, blue: 0.40)),
    ]

    var body: some View {
        OnboardingCard(
            title: "What's your main focus right now?",
            subtitle: "This shapes how aggressive your calorie target gets.",
            progress: state.progress,
            canAdvance: state.canAdvance,
            onBack: { withAnimation(Theme.Motion.spring) { state.goBack() } },
            onContinue: {
                Task { await state.commit() }
                withAnimation(Theme.Motion.spring) { state.advance() }
            }
        ) {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(MainFocus.allCases) { focus in
                    let s = style[focus]
                    OptionCard(
                        title: focus.label,
                        systemImage: s?.0,
                        tint: s?.1,
                        isSelected: state.mainFocus == focus
                    ) {
                        state.mainFocus = focus
                    }
                }
            }
        }
    }
}
