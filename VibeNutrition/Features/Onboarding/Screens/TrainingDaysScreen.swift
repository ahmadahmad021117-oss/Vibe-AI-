import SwiftUI

#Preview {
    TrainingDaysScreen(state: OnboardingState())
        .preferredColorScheme(.dark)
}

struct TrainingDaysScreen: View {
    @Bindable var state: OnboardingState
    @State private var local: Int = 3

    var body: some View {
        OnboardingCard(
            title: "How many days a week do you train?",
            subtitle: "Strength, cardio, sports — anything intentional.",
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
                NumberStepper(value: $local, range: 0...7, suffix: local == 1 ? "day" : "days")
                Spacer()
            }
        }
        .onAppear {
            local = state.trainingDaysPerWeek ?? 3
            state.trainingDaysPerWeek = local
        }
        .onChange(of: local) { _, new in state.trainingDaysPerWeek = new }
    }
}
