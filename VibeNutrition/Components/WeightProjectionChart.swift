import SwiftUI
import Charts

/// Lightweight chart that projects a user's weight trajectory from `currentKg` toward `goalKg`
/// at the selected `pace`. Reused in onboarding (pace step) and in profile (settings).
///
/// Renders a goal-realism warning underneath when `NutritionEngine.goalRealismWarning` returns one.
struct WeightProjectionChart: View {
    let currentKg: Double
    let goalKg: Double
    let pace: Pace
    /// Optional height — enables a BMI-based realism check.
    var heightCm: Double?

    private var points: [NutritionEngine.ProjectionPoint] {
        NutritionEngine.projectWeeks(currentKg: currentKg, goalKg: goalKg, pace: pace)
    }

    private var weeks: Int {
        NutritionEngine.weeksToReach(currentKg: currentKg, goalKg: goalKg, pace: pace)
    }

    private var warning: String? {
        NutritionEngine.goalRealismWarning(heightCm: heightCm, goalKg: goalKg, currentKg: currentKg)
    }

    private var direction: String {
        if abs(goalKg - currentKg) < 0.05 { return "Maintain" }
        return goalKg > currentKg ? "Gain" : "Lose"
    }

    private var etaText: String {
        if weeks == 0 { return "You're already at your goal." }
        if weeks >= 104 { return "Over 2 years to reach this goal — consider a faster pace." }
        let months = Double(weeks) / 4.345
        if weeks <= 12 { return "About \(weeks) week\(weeks == 1 ? "" : "s") to your goal." }
        return String(format: "About %.1f months to your goal.", months)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Projection")
                    .font(Theme.Typo.h3)
                    .foregroundStyle(Theme.Palette.text)
                Spacer()
                Text("\(direction) · \(pace.label)")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
            }

            chart
                .frame(height: 180)
                .padding(.top, 4)
                .accessibilityLabel("Weight projection chart")
                .accessibilityValue(etaText)

            Text(etaText)
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.textMuted)

            if let warning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.danger)
                    .padding(Theme.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Theme.Palette.danger.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: Theme.Radii.md)
                    )
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

    private var chart: some View {
        Chart(points, id: \.weekIndex) { point in
            LineMark(
                x: .value("Week", point.weekIndex),
                y: .value("Weight", point.weightKg)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(Theme.Gradients.accent)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

            AreaMark(
                x: .value("Week", point.weekIndex),
                y: .value("Weight", point.weightKg)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(
                LinearGradient(
                    colors: [Theme.Palette.accent.opacity(0.30), Theme.Palette.accent.opacity(0.0)],
                    startPoint: .top, endPoint: .bottom
                )
            )
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine().foregroundStyle(Theme.Palette.border.opacity(0.6))
                AxisValueLabel {
                    if let week = value.as(Int.self) {
                        Text("\(week)w")
                            .font(Theme.Typo.caption)
                            .foregroundStyle(Theme.Palette.textMuted)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(Theme.Palette.border.opacity(0.6))
                AxisValueLabel {
                    if let kg = value.as(Double.self) {
                        Text(String(format: "%.0f", kg))
                            .font(Theme.Typo.caption)
                            .foregroundStyle(Theme.Palette.textMuted)
                    }
                }
            }
        }
    }
}
