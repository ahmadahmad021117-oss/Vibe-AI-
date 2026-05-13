import SwiftUI

#Preview {
    MealsPerDayScreen(state: OnboardingState())
        .preferredColorScheme(.dark)
}

struct MealsPerDayScreen: View {
    @Bindable var state: OnboardingState
    @State private var local: Int = 3

    var body: some View {
        OnboardingCard(
            title: "How many meals a day do you prefer?",
            subtitle: "Snacks count if they're real meals to you.",
            progress: state.progress,
            canAdvance: state.canAdvance,
            onBack: { withAnimation(Theme.Motion.spring) { state.goBack() } },
            onContinue: {
                Task { await state.commit() }
                withAnimation(Theme.Motion.spring) { state.advance() }
            }
        ) {
            VStack {
                Spacer()
                NumberStepper(value: $local, range: 2...6, suffix: local == 1 ? "meal" : "meals")
                Spacer()
            }
        }
        .onAppear {
            local = state.mealsPerDay ?? 3
            state.mealsPerDay = local
        }
        .onChange(of: local) { _, new in state.mealsPerDay = new }
    }
}
