import SwiftUI

/// How quickly the user wants to reach their goal. The projection chart
/// appears below the option rows so the chosen pace is immediately visible.
struct PaceScreen: View {
    @Bindable var state: OnboardingState

    private let style: [Pace: (String, Color)] = [
        .slow:   ("tortoise.fill", Color(red: 0.20, green: 0.78, blue: 0.40)),
        .medium: ("figure.walk",   .blue),
        .fast:   ("hare.fill",     .red),
    ]

    var body: some View {
        OnboardingCard(
            title: "How fast do you want to go?",
            subtitle: "We'll cap things automatically if a pace is too aggressive.",
            progress: state.progress,
            canAdvance: state.canAdvance,
            onBack: { withAnimation(Theme.Motion.spring) { state.goBack() } },
            onContinue: {
                Task { await state.commit() }
                withAnimation(Theme.Motion.spring) { state.advance() }
            }
        ) {
            VStack(spacing: Theme.Spacing.md) {
                VStack(spacing: Onboarding.rowGap) {
                    ForEach(Pace.allCases) { pace in
                        let s = style[pace]
                        OptionCard(
                            title: pace.label,
                            subtitle: pace.subtitle,
                            systemImage: s?.0,
                            tint: s?.1,
                            isSelected: state.pace == pace
                        ) {
                            state.pace = pace
                        }
                    }
                }

                if let current = state.currentWeightKg, let goal = state.goalWeightKg {
                    WeightProjectionChart(
                        currentKg: current,
                        goalKg: goal,
                        pace: state.pace,
                        heightCm: state.heightCm
                    )
                    .transition(.opacity)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

#Preview {
    let state = OnboardingState()
    state.currentWeightKg = 70
    state.goalWeightKg = 75
    state.goal = .gainWeight
    return PaceScreen(state: state)
        .preferredColorScheme(.dark)
}
