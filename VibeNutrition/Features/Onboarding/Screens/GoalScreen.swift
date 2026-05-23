import SwiftUI

#Preview {
    GoalScreen(state: OnboardingState())
        .preferredColorScheme(.dark)
}

struct GoalScreen: View {
    @Bindable var state: OnboardingState

    // Each row gets a recognisable shape + colour. The previous monochrome
    // arrow.circles all read the same at a glance — users were comparing
    // labels, not icons.
    private let style: [GoalType: (String, Color)] = [
        .loseWeight:    ("flame.fill",                      .orange),
        .gainWeight:    ("chart.line.uptrend.xyaxis",       Color(red: 0.20, green: 0.78, blue: 0.40)),
        .buildMuscle:   ("dumbbell.fill",                   .blue),
        .maintain:      ("equal.square.fill",               .teal),
        .recomp:        ("arrow.triangle.2.circlepath",     .purple),
        .improveHealth: ("heart.fill",                      .pink),
    ]

    var body: some View {
        OnboardingCard(
            title: "What's your main goal?",
            subtitle: "We'll tune your calories and macros to match.",
            progress: state.progress,
            canAdvance: state.canAdvance,
            onBack: nil,
            onContinue: {
                Task { await state.commit() }
                withAnimation(Theme.Motion.spring) { state.advance() }
            }
        ) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(GoalType.allCases) { goal in
                        let s = style[goal]
                        OptionCard(
                            title: goal.label,
                            systemImage: s?.0 ?? "circle",
                            tint: s?.1,
                            isSelected: state.goal == goal
                        ) {
                            state.goal = goal
                        }
                    }
                }
            }
        }
    }
}
