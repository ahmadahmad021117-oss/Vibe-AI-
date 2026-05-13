import SwiftUI

private func kgToLb(_ kg: Double) -> Double { kg * 2.2046226218 }
private func lbToKg(_ lb: Double) -> Double { lb / 2.2046226218 }

struct CurrentWeightScreen: View {
    @Bindable var state: OnboardingState

    var body: some View {
        OnboardingCard(
            title: "How much do you weigh now?",
            subtitle: nil,
            progress: state.progress,
            canAdvance: state.canAdvance,
            onBack: { withAnimation(Theme.Motion.spring) { state.goBack() } },
            onContinue: {
                Task { await state.commit() }
                withAnimation(Theme.Motion.spring) { state.advance() }
            }
        ) {
            WeightEntry(unitsPref: $state.unitsPref, weightKg: $state.currentWeightKg)
        }
    }
}

struct GoalWeightScreen: View {
    @Bindable var state: OnboardingState

    var body: some View {
        OnboardingCard(
            title: "And your goal weight?",
            subtitle: "Pick a realistic target. You can change this later.",
            progress: state.progress,
            canAdvance: state.canAdvance,
            onBack: { withAnimation(Theme.Motion.spring) { state.goBack() } },
            onContinue: {
                Task { await state.commit() }
                withAnimation(Theme.Motion.spring) { state.advance() }
            }
        ) {
            WeightEntry(unitsPref: $state.unitsPref, weightKg: $state.goalWeightKg)
        }
    }
}

private struct WeightEntry: View {
    @Binding var unitsPref: UnitsPref
    @Binding var weightKg: Double?

    @State private var displayValue: Double = 70

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            unitToggle

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(formattedDisplay)
                    .font(Theme.Typography.numeralXL)
                    .foregroundStyle(Theme.Palette.text)
                    .contentTransition(.numericText(value: displayValue))
                Text(unitsPref == .metric ? "kg" : "lb")
                    .font(Theme.Typography.h3)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            .frame(maxWidth: .infinity)

            Slider(
                value: $displayValue,
                in: unitsPref == .metric ? 35...200 : 77...440,
                step: 0.5
            )
            .tint(Theme.Palette.accent)
            .onChange(of: displayValue) { _, new in
                Haptics.select()
                weightKg = unitsPref == .metric ? new : lbToKg(new)
            }
        }
        .onAppear {
            if let kg = weightKg {
                displayValue = unitsPref == .metric ? kg : kgToLb(kg)
            } else {
                weightKg = unitsPref == .metric ? displayValue : lbToKg(displayValue)
            }
        }
        .onChange(of: unitsPref) { _, _ in
            if let kg = weightKg {
                displayValue = unitsPref == .metric ? kg : kgToLb(kg)
            }
        }
    }

    private var formattedDisplay: String {
        String(format: "%.1f", displayValue)
    }

    private var unitToggle: some View {
        HStack(spacing: 0) {
            ForEach(UnitsPref.allCases) { unit in
                Button {
                    Haptics.select()
                    unitsPref = unit
                } label: {
                    Text(unit.label)
                        .font(Theme.Typography.bodyBold)
                        .foregroundStyle(unitsPref == unit ? Theme.Palette.bg : Theme.Palette.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(unitsPref == unit ? Theme.Palette.accent : Color.clear)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(Theme.Palette.surface, in: Capsule())
    }
}
