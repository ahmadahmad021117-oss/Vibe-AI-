import SwiftUI

struct SexScreen: View {
    @Bindable var state: OnboardingState

    private let icons: [SexType: String] = [
        .male: "figure.stand",
        .female: "figure.stand.dress",
        .other: "person.fill.questionmark",
    ]

    var body: some View {
        OnboardingCard(
            title: "What's your biological sex?",
            subtitle: "Calorie math (Mifflin-St Jeor) needs this. It stays private.",
            progress: state.progress,
            canAdvance: state.canAdvance,
            onBack: { withAnimation(Theme.Motion.spring) { state.goBack() } },
            onContinue: {
                Task { await state.commit() }
                withAnimation(Theme.Motion.spring) { state.advance() }
            }
        ) {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(SexType.allCases) { sex in
                    OptionCard(
                        title: sex.label,
                        systemImage: icons[sex],
                        isSelected: state.sex == sex
                    ) {
                        state.sex = sex
                    }
                }
            }
        }
    }
}
