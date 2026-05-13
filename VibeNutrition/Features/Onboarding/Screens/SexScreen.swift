import SwiftUI

#Preview {
    SexScreen(state: OnboardingState())
        .preferredColorScheme(.dark)
}

struct SexScreen: View {
    @Bindable var state: OnboardingState

    private let icons: [SexType: String] = [
        .male: "figure.stand",
        .female: "figure.stand.dress",
        .other: "person.fill",
    ]

    private let subtitles: [SexType: String] = [
        .other: "We'll use a neutral calorie estimate.",
    ]

    var body: some View {
        OnboardingCard(
            title: "Sex assigned at birth",
            subtitle: "Used for calorie math (Mifflin-St Jeor). Stays private.",
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
                        subtitle: subtitles[sex],
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
