import SwiftUI

/// Asks the user how quickly they want to reach their goal. Shows a live projection chart
/// underneath so they can see what the chosen pace actually means.
struct PaceScreen: View {
    @Bindable var state: OnboardingState

    private let style: [Pace: (String, Color)] = [
        .slow:   ("tortoise.fill", Color(red: 0.20, green: 0.78, blue: 0.40)),
        .medium: ("figure.walk",   .blue),
        .fast:   ("hare.fill",     .red),
    ]

    var body: some View {
        OnboardingCard(
            title: "How quickly do you want to reach your goal?",
            subtitle: "You can change this any time. We'll cap things automatically if a pace is too aggressive.",
            progress: state.progress,
            canAdvance: state.canAdvance,
            onBack: { withAnimation(Theme.Motion.spring) { state.goBack() } },
            onContinue: {
                Task { await state.commit() }
                withAnimation(Theme.Motion.spring) { state.advance() }
            }
        ) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.md) {
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

                    if let current = state.currentWeightKg, let goal = state.goalWeightKg {
                        WeightProjectionChart(
                            currentKg: current,
                            goalKg: goal,
                            pace: state.pace,
                            heightCm: state.heightCm
                        )
                        .transition(.opacity)
                    }
                }
                .padding(.bottom, Theme.Spacing.md)
            }
        }
    }
}
