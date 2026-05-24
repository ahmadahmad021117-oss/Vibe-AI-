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
            WeightEntry(unitsPref: $state.unitsPref, weightKg: $state.currentWeightKg, hint: nil)
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
            WeightEntry(unitsPref: $state.unitsPref, weightKg: $state.goalWeightKg, hint: state.goalWeightHint)
        }
        .onAppear {
            // Seed the goal-weight slider in the direction of the chosen goal
            // (e.g. +5 kg for Gain) so the projection isn't a 0-kg trajectory.
            if state.goalWeightKg == nil, let cur = state.currentWeightKg, let goal = state.goal {
                state.goalWeightKg = cur + goal.defaultDeltaKg
            }
        }
    }
}

/// Centered weight control used by both Current and Goal weight screens.
/// Sits inside the standard onboarding content area.
private struct WeightEntry: View {
    @Binding var unitsPref: UnitsPref
    @Binding var weightKg: Double?
    let hint: String?

    @State private var displayValue: Double = 70

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer(minLength: 0)

            unitToggle
                .frame(maxWidth: 220)

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(formattedDisplay)
                    .font(Theme.Typo.numeralXL)
                    .foregroundStyle(Theme.Palette.text)
                    .contentTransition(.numericText(value: displayValue))
                Text(unitsPref == .metric ? "kg" : "lb")
                    .font(Theme.Typo.h3)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            .frame(maxWidth: .infinity)

            Slider(
                value: $displayValue,
                in: unitsPref == .metric ? 35...200 : 77...440,
                step: 0.5
            )
            .tint(Theme.Palette.accent)
            .padding(.horizontal, Theme.Spacing.lg)
            .onChange(of: displayValue) { _, new in
                Haptics.select()
                weightKg = unitsPref == .metric ? new : lbToKg(new)
            }

            if let hint {
                Text(hint)
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.warning)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .transition(.opacity)
            }

            Spacer(minLength: 0)
        }
        .animation(Theme.Motion.spring, value: hint)
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
        displayValue.grouped(1)
    }

    private var unitToggle: some View {
        HStack(spacing: 0) {
            ForEach(UnitsPref.allCases) { unit in
                Button {
                    Haptics.select()
                    unitsPref = unit
                } label: {
                    Text(unit.label)
                        .font(Theme.Typo.bodyBold)
                        .foregroundStyle(unitsPref == unit ? Theme.Palette.bg : Theme.Palette.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(unitsPref == unit ? Theme.Palette.accent : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.Palette.surface, in: Capsule())
    }
}

#Preview("Current weight") {
    CurrentWeightScreen(state: OnboardingState())
        .preferredColorScheme(.dark)
}

#Preview("Goal weight") {
    let state = OnboardingState()
    state.currentWeightKg = 75
    return GoalWeightScreen(state: state)
        .preferredColorScheme(.dark)
}
