import SwiftUI

struct GoalScreen: View {
    @Bindable var state: OnboardingState

    private let icons: [GoalType: String] = [
        .loseWeight: "arrow.down.right.circle",
        .gainWeight: "arrow.up.right.circle",
        .buildMuscle: "figure.strengthtraining.traditional",
        .maintain: "equal.circle",
        .recomp: "arrow.triangle.2.circlepath.circle",
        .improveHealth: "heart.circle",
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
                        OptionCard(
                            title: goal.label,
                            systemImage: icons[goal] ?? "circle",
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
