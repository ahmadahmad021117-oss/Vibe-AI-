import SwiftUI

/// How quickly the user wants to reach their goal. Three options, same
/// shell + row height as every other option screen. The projection chart
/// lives on the Plan Preview after onboarding — keeping the question
/// itself clean makes the cadence of the flow consistent.
struct PaceScreen: View {
    @Bindable var state: OnboardingState

    private let style: [Pace: (String, Color)] = [
        .slow:   ("tortoise.fill", Color(red: 0.20, green: 0.78, blue: 0.40)),
        .medium: ("figure.walk", .blue),
        .fast:   ("hare.fill", .red),
    ]

    var body: some View {
        OnboardingCard(
            title: "How fast do you want to go?",
            subtitle: "We'll cap a pace that's too aggressive.",
            progress: state.progress,
            canAdvance: state.canAdvance,
            onBack: { withAnimation(Theme.Motion.spring) { state.goBack() } },
            onContinue: {
                Task { await state.commit() }
                withAnimation(Theme.Motion.spring) { state.advance() }
            }
        ) {
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
