import SwiftUI

struct PlanPreviewView: View {
    let result: NutritionEngine.Result
    let inputs: NutritionEngine.Inputs
    var unitsPref: UnitsPref = .metric
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    header

                    KcalRing(kcal: result.kcalTarget)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.lg)

                    macroSplit

                    weightSummary

                    weeklyProjection

                    rationale

                    // Last row of `rationale` (the Goal-adjustment line) was
                    // landing behind the Start-your-plan button. Reserve
                    // enough scroll inset to clear the floating actions bar.
                    Spacer(minLength: 160)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.xl)
            }

            VStack {
                Spacer()
                // CTA was "See what's included" — confusing because users
                // didn't know they were about to hit the paywall. New CTA
                // reads as a positive forward action.
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [Theme.Palette.bg.opacity(0), Theme.Palette.bg],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 28)
                    .allowsHitTesting(false)

                    PrimaryButton(title: "Start your plan") {
                        onContinue()
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.sm)
                    .padding(.bottom, Theme.Spacing.lg)
                    .background(Theme.Palette.bg)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your plan")
                .font(Theme.Typo.h1)
                .foregroundStyle(Theme.Palette.text)
            Text(goalSubtitle)
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.textMuted)
            // Narrative line: turns the screen from a wall of numbers into
            // a "here's your specific path" moment. Only shows when we can
            // compute a meaningful weeks-to-goal estimate.
            if let weeks = weeksToGoal {
                Text("On this plan you'll hit your goal in about \(weeks) weeks.")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.accent)
                    .padding(.top, 2)
            }
        }
    }

    /// Rough weeks-to-goal estimate from |goal − current| / |weeklyDeltaKg|.
    /// Returns nil when goal weight is missing, delta is ~0 (maintain), or
    /// the user already overshot in the right direction.
    private var weeksToGoal: Int? {
        guard let goalKg = inputs.goalWeightKg else { return nil }
        let deltaKg = goalKg - inputs.weightKg
        guard abs(deltaKg) >= 0.5 else { return nil }
        guard abs(result.weeklyDeltaKg) >= 0.05 else { return nil }
        // Only show when sign of progression matches direction needed.
        if (deltaKg < 0) != (result.weeklyDeltaKg < 0) { return nil }
        let weeks = Int((abs(deltaKg) / abs(result.weeklyDeltaKg)).rounded())
        guard weeks >= 1, weeks <= 78 else { return nil }
        return weeks
    }

    private var goalSubtitle: String {
        switch inputs.goal {
        case .loseWeight:    return "Calibrated for steady fat loss."
        case .gainWeight:    return "Calibrated for lean weight gain."
        case .buildMuscle:   return "Calibrated for muscle growth."
        case .maintain:      return "Calibrated to hold your current weight."
        case .recomp:        return "Calibrated for body recomposition."
        case .improveHealth: return "Calibrated for steady, sustainable health."
        }
    }

    private var macroSplit: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                Text("Daily macros")
                    .font(Theme.Typo.h3)
                    .foregroundStyle(Theme.Palette.text)
                Spacer()
            }
            MacroSplitBar(
                proteinG: result.proteinG,
                carbsG: result.carbsG,
                fatG: result.fatG
            )
            HStack(spacing: Theme.Spacing.md) {
                MacroChip(label: "Protein", grams: result.proteinG, color: Theme.Palette.accent)
                MacroChip(label: "Carbs", grams: result.carbsG, color: Theme.Palette.accentDeep)
                MacroChip(label: "Fat", grams: result.fatG, color: Theme.Palette.accentAlt)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

    private var weightSummary: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Weight")
                .font(Theme.Typo.h3)
                .foregroundStyle(Theme.Palette.text)
            HStack(spacing: Theme.Spacing.md) {
                weightStat(label: "Current", value: weightText(inputs.weightKg))
                if let goalKg = inputs.goalWeightKg {
                    Image(systemName: "arrow.right")
                        .font(Theme.Typo.body)
                        .foregroundStyle(Theme.Palette.textMuted)
                    weightStat(label: "Target", value: weightText(goalKg))
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

    private func weightStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Theme.Typo.caption)
                .foregroundStyle(Theme.Palette.textMuted)
            Text(value)
                .font(Theme.Typo.numeralLG)
                .foregroundStyle(Theme.Palette.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func weightText(_ kg: Double) -> String {
        switch unitsPref {
        case .metric:
            return "\(String(format: "%.1f", kg)) kg"
        case .imperial:
            return "\(String(format: "%.1f", kg * 2.2046226218)) lb"
        }
    }

    private var weeklyProjection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Weekly projection")
                .font(Theme.Typo.h3)
                .foregroundStyle(Theme.Palette.text)
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(weeklyDeltaText)
                    .font(Theme.Typo.numeralLG)
                    .foregroundStyle(deltaTint)
                Text("per week")
                    .font(Theme.Typo.body)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            Text("Estimates are averages. Real progress depends on adherence, sleep, training, and stress — give it 2–3 weeks before adjusting.")
                .font(Theme.Typo.caption)
                .foregroundStyle(Theme.Palette.textMuted)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

    private var weeklyDeltaText: String {
        let kg = result.weeklyDeltaKg
        let prefix = kg > 0 ? "+" : ""
        switch unitsPref {
        case .metric:
            return "\(prefix)\(String(format: "%.2f", kg)) kg"
        case .imperial:
            return "\(prefix)\(String(format: "%.2f", kg * 2.2046226218)) lb"
        }
    }

    private var deltaTint: Color {
        switch inputs.goal {
        case .loseWeight, .recomp: return Theme.Palette.success
        case .gainWeight, .buildMuscle: return Theme.Palette.accent
        case .maintain, .improveHealth: return Theme.Palette.textMuted
        }
    }

    private var rationale: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("How we got there")
                .font(Theme.Typo.h3)
                .foregroundStyle(Theme.Palette.text)
            BulletRow(label: "BMR (Mifflin-St Jeor)", value: "\(result.bmr.grouped) kcal")
            BulletRow(label: "Activity multiplier", value: String(format: "×%.2f", result.activityMultiplier))
            BulletRow(label: "Daily energy needs (TDEE)", value: "\(result.tdee.grouped) kcal")
            BulletRow(label: "Goal adjustment", value: deltaPercentText)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

    private var deltaPercentText: String {
        let pct = (Double(result.kcalTarget) / Double(result.tdee) - 1) * 100
        let prefix = pct >= 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.0f", pct))%"
    }
}

// MARK: - Subviews

private struct KcalRing: View {
    let kcal: Int
    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Palette.surface, lineWidth: 20)
            Circle()
                .trim(from: 0, to: 0.92)
                .stroke(Theme.Gradients.accent, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(kcal.grouped)
                    .font(Theme.Typo.numeralXL)
                    .foregroundStyle(Theme.Palette.text)
                    .contentTransition(.numericText(value: Double(kcal)))
                Text("kcal / day")
                    .font(Theme.Typo.body)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
        }
        .frame(width: 220, height: 220)
    }
}

private struct MacroSplitBar: View {
    let proteinG: Int
    let carbsG: Int
    let fatG: Int

    var body: some View {
        GeometryReader { proxy in
            let total = max(1, Double(proteinG * 4 + carbsG * 4 + fatG * 9))
            let pK = Double(proteinG * 4) / total
            let cK = Double(carbsG * 4) / total
            let fK = Double(fatG * 9) / total
            HStack(spacing: 2) {
                Rectangle().fill(Theme.Palette.accent).frame(width: proxy.size.width * pK)
                Rectangle().fill(Theme.Palette.accentDeep).frame(width: proxy.size.width * cK)
                Rectangle().fill(Theme.Palette.accentAlt).frame(width: proxy.size.width * fK)
            }
            .clipShape(Capsule())
        }
        .frame(height: 12)
    }
}

private struct MacroChip: View {
    let label: String
    let grams: Int
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label)
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            Text("\(grams) g")
                .font(Theme.Typo.bodyBold)
                .foregroundStyle(Theme.Palette.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BulletRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.textMuted)
            Spacer()
            Text(value)
                .font(Theme.Typo.bodyBold)
                .foregroundStyle(Theme.Palette.text)
        }
    }
}

#Preview {
    let inputs = NutritionEngine.Inputs(
        sex: .male, age: 28, heightCm: 180, weightKg: 80,
        trainingDaysPerWeek: 4, avgSteps: 7500,
        goal: .loseWeight, mainFocus: .fatLoss
    )
    return PlanPreviewView(result: NutritionEngine.compute(inputs), inputs: inputs) {}
        .preferredColorScheme(.dark)
}
