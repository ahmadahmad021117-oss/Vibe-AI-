import SwiftUI

struct GoalScreen: View {
    @Bindable var state: OnboardingState

    // The Goal step is the first screen — keep it scannable with just the
    // three primary directions. Build muscle / Recomp / Improve health are
    // captured later (MainFocus screen) and still parse from server data.
    private let visibleGoals: [GoalType] = [.loseWeight, .gainWeight, .maintain]

    private let style: [GoalType: (String, Color)] = [
        .loseWeight:    ("flame.fill",                      .orange),
        .gainWeight:    ("chart.line.uptrend.xyaxis",       Color(red: 0.20, green: 0.78, blue: 0.40)),
        .maintain:      ("equal.square.fill",               .teal),
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
            VStack(spacing: Onboarding.rowGap) {
                ForEach(visibleGoals) { goal in
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

#Preview {
    GoalScreen(state: OnboardingState())
        .preferredColorScheme(.dark)
}
