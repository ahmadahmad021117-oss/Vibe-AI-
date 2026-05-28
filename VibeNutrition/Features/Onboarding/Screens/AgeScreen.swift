import SwiftUI

struct AgeScreen: View {
    @Bindable var state: OnboardingState
    @State private var local: Int = 22

    var body: some View {
        OnboardingCard(
            title: "How old are you?",
            subtitle: nil,
            progress: state.progress,
            canAdvance: state.canAdvance,
            onBack: { withAnimation(Theme.Motion.spring) { state.goBack() } },
            onContinue: {
                Task { await state.commit() }
                withAnimation(Theme.Motion.spring) { state.advance() }
            }
        ) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                NumberStepper(value: $local, range: 13...100, suffix: "years")
                Spacer(minLength: 0)
            }
        }
        .onAppear {
            local = state.age ?? 22
            state.age = local
        }
        .onChange(of: local) { _, new in state.age = new }
    }
}

#Preview {
    AgeScreen(state: OnboardingState())
        .preferredColorScheme(.dark)
}
