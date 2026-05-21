import SwiftUI
import Charts

/// Lightweight chart that projects a user's weight trajectory from `currentKg` toward `goalKg`
/// at the selected `pace`. Reused in onboarding (pace step) and on the dashboard.
///
/// The X domain is pinned to the actual data range so the line always spans the chart, regardless
/// of which pace the user picks. The Y domain is padded so the line never hugs the edges.
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
        if weeks >= 104 { return "Over 2 years to reach this goal — try a faster pace." }
        let months = Double(weeks) / 4.345
        if weeks <= 12 { return "≈ \(weeks) week\(weeks == 1 ? "" : "s") to your goal." }
        return String(format: "≈ %.1f months to your goal.", months)
    }

    private var goalDateText: String? {
        guard weeks > 0, let last = points.last else { return nil }
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: last.date)
    }

    /// Pads the Y domain so endpoints never sit flush against the top/bottom border.
    private var yDomain: ClosedRange<Double> {
        let lo = min(currentKg, goalKg)
        let hi = max(currentKg, goalKg)
        let span = max(0.5, hi - lo)
        let pad = span * 0.22
        return (lo - pad)...(hi + pad)
    }

    private var xMax: Int {
        max(1, points.last?.weekIndex ?? weeks)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Title + summary
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Projection")
                        .font(Theme.Typo.h3)
                        .foregroundStyle(Theme.Palette.text)
                    Text("\(direction) · \(pace.label)")
                        .font(Theme.Typo.caption)
                        .foregroundStyle(Theme.Palette.textMuted)
                }
                Spacer()
                deltaBadge
            }

            chart
                .frame(height: 200)
                .clipped()
                .accessibilityLabel("Weight projection chart")
                .accessibilityValue(etaText)

            // Endpoint legend
            HStack(spacing: Theme.Spacing.md) {
                legendItem(color: Theme.Palette.textMuted, label: "Now", value: weightString(currentKg))
                Rectangle()
                    .fill(Theme.Palette.border)
                    .frame(width: 1, height: 24)
                legendItem(color: Theme.Palette.accent, label: "Goal", value: weightString(goalKg))
                Spacer()
                if let goalDateText {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("ETA")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.Palette.textMuted)
                        Text(goalDateText)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Palette.text)
                    }
                }
            }

            Text(etaText)
                .font(Theme.Typo.caption)
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
        .background(
            RoundedRectangle(cornerRadius: Theme.Radii.lg, style: .continuous)
                .fill(Theme.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radii.lg, style: .continuous)
                .stroke(Theme.Palette.border, lineWidth: 1)
        )
        // Keep just the data animating; jiggling the container made layout look buggy.
        .animation(.easeInOut(duration: 0.25), value: points)
    }

    private var deltaBadge: some View {
        let delta = goalKg - currentKg
        let absDelta = String(format: "%.1f kg", abs(delta))
        let isLoss = delta < 0
        let isMaintain = abs(delta) < 0.05
        let color: Color = isMaintain ? Theme.Palette.textMuted
                                       : (isLoss ? Theme.Palette.accent : Theme.Palette.accentAlt)
        let symbol = isMaintain ? "equal" : (isLoss ? "arrow.down" : "arrow.up")
        return HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
            Text(absDelta)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.15), in: Capsule())
    }

    private func legendItem(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textMuted)
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Palette.text)
            }
        }
    }

    private func weightString(_ kg: Double) -> String {
        String(format: "%.1f kg", kg)
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            // Goal reference line
            RuleMark(y: .value("Goal", goalKg))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Theme.Palette.accent.opacity(0.55))
                .annotation(position: .topTrailing, alignment: .trailing, spacing: 2) {
                    Text("Goal \(String(format: "%.1f", goalKg))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.Palette.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Palette.accent.opacity(0.15), in: Capsule())
                }

            // Filled area under the curve
            ForEach(points, id: \.weekIndex) { point in
                AreaMark(
                    x: .value("Week", point.weekIndex),
                    y: .value("Weight", point.weightKg)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.Palette.accent.opacity(0.32), Theme.Palette.accent.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            }

            // Trajectory line
            ForEach(points, id: \.weekIndex) { point in
                LineMark(
                    x: .value("Week", point.weekIndex),
                    y: .value("Weight", point.weightKg)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Theme.Gradients.accent)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .shadow(color: Theme.Palette.accent.opacity(0.35), radius: 6, y: 3)
            }

            // Start marker
            if let first = points.first {
                PointMark(
                    x: .value("Week", first.weekIndex),
                    y: .value("Weight", first.weightKg)
                )
                .symbol {
                    ZStack {
                        Circle().fill(Theme.Palette.bg).frame(width: 12, height: 12)
                        Circle().fill(Theme.Palette.textMuted).frame(width: 8, height: 8)
                    }
                }
            }

            // End marker
            if let last = points.last {
                PointMark(
                    x: .value("Week", last.weekIndex),
                    y: .value("Weight", last.weightKg)
                )
                .symbol {
                    ZStack {
                        Circle()
                            .fill(Theme.Palette.accent.opacity(0.25))
                            .frame(width: 18, height: 18)
                        Circle().fill(Theme.Palette.bg).frame(width: 12, height: 12)
                        Circle().fill(Theme.Palette.accent).frame(width: 8, height: 8)
                    }
                }
            }
        }
        // Pin X domain to the actual data so the line ALWAYS fills the chart.
        .chartXScale(domain: 0...xMax)
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: xTicks) { value in
                AxisGridLine().foregroundStyle(Theme.Palette.border.opacity(0.5))
                AxisTick().foregroundStyle(Theme.Palette.border)
                AxisValueLabel {
                    if let week = value.as(Int.self) {
                        Text(weekLabel(week))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.Palette.textMuted)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Theme.Palette.border.opacity(0.5))
                AxisValueLabel {
                    if let kg = value.as(Double.self) {
                        Text(String(format: "%.0f", kg))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.Palette.textMuted)
                    }
                }
            }
        }
        .chartPlotStyle { plot in
            plot.background(
                LinearGradient(
                    colors: [Theme.Palette.surface.opacity(0.0), Theme.Palette.accent.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                )
            )
        }
    }

    /// Pick ~5 evenly-spaced integer ticks anchored to the data range so the right edge
    /// always coincides with the final data point.
    private var xTicks: [Int] {
        let last = xMax
        if last <= 6 { return Array(0...last) }
        let desired = 5
        let step = max(1, Int((Double(last) / Double(desired - 1)).rounded()))
        var ticks: [Int] = stride(from: 0, through: last, by: step).map { $0 }
        if ticks.last != last { ticks.append(last) }
        return ticks
    }

    private func weekLabel(_ week: Int) -> String {
        if xMax <= 12 { return "\(week)w" }
        // Switch to months for longer projections so labels stay readable.
        let months = Double(week) / 4.345
        if week == 0 { return "0" }
        return String(format: "%.0fmo", months)
    }
}

#Preview {
    VStack(spacing: 16) {
        WeightProjectionChart(currentKg: 84, goalKg: 75, pace: .medium, heightCm: 178)
        WeightProjectionChart(currentKg: 70, goalKg: 78, pace: .fast, heightCm: 178)
    }
    .padding()
    .background(Theme.Palette.bg)
    .preferredColorScheme(.dark)
}
