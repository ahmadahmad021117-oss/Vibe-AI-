import SwiftUI

struct HeightScreen: View {
    @Bindable var state: OnboardingState
    @State private var cm: Double = 175

    var body: some View {
        OnboardingCard(
            title: "How tall are you?",
            subtitle: nil,
            progress: state.progress,
            canAdvance: state.canAdvance,
            onBack: { withAnimation(Theme.Motion.spring) { state.goBack() } },
            onContinue: {
                Task { await state.commit() }
                withAnimation(Theme.Motion.spring) { state.advance() }
            }
        ) {
            VStack(spacing: Theme.Spacing.lg) {
                Spacer(minLength: 0)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(displayValue)
                        .font(Theme.Typo.numeralXL)
                        .foregroundStyle(Theme.Palette.text)
                    Text(state.unitsPref == .metric ? "cm" : "")
                        .font(Theme.Typo.h3)
                        .foregroundStyle(Theme.Palette.textMuted)
                }
                .frame(maxWidth: .infinity)

                Slider(value: $cm, in: 130...220, step: 1)
                    .tint(Theme.Palette.accent)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .onChange(of: cm) { _, new in
                        Haptics.select()
                        state.heightCm = new
                    }

                Spacer(minLength: 0)
            }
        }
        .onAppear {
            cm = state.heightCm ?? 175
            state.heightCm = cm
        }
    }

    private var displayValue: String {
        if state.unitsPref == .metric {
            return "\(Int(cm.rounded()))"
        } else {
            let totalInches = cm / 2.54
            let feet = Int(totalInches / 12)
            let inches = Int(totalInches.truncatingRemainder(dividingBy: 12).rounded())
            return "\(feet)'\(inches)\""
        }
    }
}

#Preview {
    HeightScreen(state: OnboardingState())
        .preferredColorScheme(.dark)
}
