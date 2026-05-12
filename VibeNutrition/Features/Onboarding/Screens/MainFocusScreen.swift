import SwiftUI

struct MainFocusScreen: View {
    @Bindable var state: OnboardingState

    private let icons: [MainFocus: String] = [
        .fatLoss: "flame.fill",
        .muscleGain: "dumbbell.fill",
        .recomp: "arrow.triangle.2.circlepath",
        .generalHealth: "leaf.fill",
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
                    OptionCard(
                        title: focus.label,
                        systemImage: icons[focus],
                        isSelected: state.mainFocus == focus
                    ) {
                        state.mainFocus = focus
                    }
                }
            }
        }
    }
}
