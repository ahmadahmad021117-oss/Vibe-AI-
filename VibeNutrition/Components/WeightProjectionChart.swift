import SwiftUI
import Charts

/// Projection chart with a draggable pin. The pin reads its date / weight into a static row
/// above the chart (no floating tooltip), so the chart can be safely clipped to its frame and
/// the layout stays tight regardless of pin position.
struct WeightProjectionChart: View {
    let currentKg: Double
    let goalKg: Double
    let pace: Pace
    /// Optional height — enables a BMI-based realism check.
    var heightCm: Double?

    /// Week the user has scrubbed to. nil = no scrub yet → defaults to the goal-week endpoint.
    @State private var pinWeek: Int?

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

    /// Pads the Y domain a little so endpoints don't sit flush against the top/bottom border,
    /// but kept tight so the line gets most of the vertical real estate rather than the area fill.
    private var yDomain: ClosedRange<Double> {
        let lo = min(currentKg, goalKg)
        let hi = max(currentKg, goalKg)
        let span = max(0.5, hi - lo)
        let pad = span * 0.12
        return (lo - pad)...(hi + pad)
    }

    private var xMax: Int {
        max(1, points.last?.weekIndex ?? weeks)
    }

    /// The week the pin currently sits on. Defaults to the goal week so there's always
    /// something visible to grab.
    private var effectivePinWeek: Int {
        max(0, min(xMax, pinWeek ?? xMax))
    }

    /// Projected weight at a given week (linear interpolation along the line).
    private func weight(atWeek week: Int) -> Double {
        let diff = goalKg - currentKg
        if abs(diff) < 0.05 { return currentKg }
        let dir: Double = diff > 0 ? 1 : -1
        let perWeek = pace.weeklyKg * dir
        let projected = currentKg + perWeek * Double(week)
        return dir > 0 ? min(goalKg, projected) : max(goalKg, projected)
    }

    private func date(atWeek week: Int) -> Date {
        Calendar.current.date(byAdding: .weekOfYear, value: week, to: Date()) ?? Date()
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Title + delta
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

            // Static scrubber row — replaces the floating tooltip so the chart can stay clipped.
            scrubberRow

            chart
                .frame(height: 160)
                .clipped()
                .accessibilityLabel("Weight projection chart. Drag the pin to scrub through weeks.")
                .accessibilityValue(etaText)

            // Endpoint legend
            HStack(spacing: Theme.Spacing.md) {
                legendDot(color: Theme.Palette.textMuted, label: "Now", value: weightString(currentKg))
                legendDot(color: Theme.Palette.accent, label: "Goal", value: weightString(goalKg))
                Spacer()
                Text(etaText)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Palette.textMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }

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
        .onChange(of: pace) { _, _ in pinWeek = nil }
        .animation(.easeInOut(duration: 0.25), value: points)
    }

    // MARK: - Scrubber row (replaces floating tooltip)

    private var scrubberRow: some View {
        let week = effectivePinWeek
        let w = weight(atWeek: week)
        return HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "scope")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Palette.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(Self.dateFormatter.string(from: date(atWeek: week)))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textMuted)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", w))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Palette.text)
                        .contentTransition(.numericText(value: w))
                    Text("kg")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textMuted)
                }
            }
            Spacer()
            Text(weekSubtitle(week))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.Palette.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.Palette.accent.opacity(0.15), in: Capsule())
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radii.md, style: .continuous)
                .fill(Theme.Palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radii.md, style: .continuous)
                .stroke(Theme.Palette.border.opacity(0.6), lineWidth: 0.5)
        )
        .animation(.easeInOut(duration: 0.18), value: week)
    }

    // MARK: - Delta + Legend

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

    private func legendDot(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.Palette.textMuted)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Palette.text)
        }
    }

    private func weightString(_ kg: Double) -> String {
        String(format: "%.1f kg", kg)
    }

    private func weekSubtitle(_ week: Int) -> String {
        if week == 0 { return "Now" }
        if week == xMax { return "Goal" }
        let months = Double(week) / 4.345
        if week <= 12 { return "Week \(week)" }
        return String(format: "%.1f mo", months)
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            // Goal reference line
            RuleMark(y: .value("Goal", goalKg))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Theme.Palette.accent.opacity(0.5))

            // Filled area under the curve — kept subtle so it doesn't dominate.
            ForEach(points, id: \.weekIndex) { point in
                AreaMark(
                    x: .value("Week", point.weekIndex),
                    y: .value("Weight", point.weightKg)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.Palette.accent.opacity(0.22), Theme.Palette.accent.opacity(0.0)],
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
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }

            // Static start marker (always at week 0)
            if let first = points.first {
                PointMark(
                    x: .value("Week", first.weekIndex),
                    y: .value("Weight", first.weightKg)
                )
                .symbol {
                    ZStack {
                        Circle().fill(Theme.Palette.bg).frame(width: 10, height: 10)
                        Circle().fill(Theme.Palette.textMuted).frame(width: 6, height: 6)
                    }
                }
            }
        }
        .chartXScale(domain: 0...xMax)
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: xTicks) { value in
                AxisGridLine().foregroundStyle(Theme.Palette.border.opacity(0.5))
                AxisTick().foregroundStyle(Theme.Palette.border)
                AxisValueLabel {
                    if let week = value.as(Int.self) {
                        Text(weekLabel(week))
                            .font(.system(size: 9, weight: .medium))
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
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Theme.Palette.textMuted)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                pinOverlay(proxy: proxy, geo: geo)
            }
        }
    }

    @ViewBuilder
    private func pinOverlay(proxy: ChartProxy, geo: GeometryProxy) -> some View {
        let plot: CGRect = {
            if let anchor = proxy.plotFrame { return geo[anchor] }
            return .zero
        }()
        let week = effectivePinWeek
        let w = weight(atWeek: week)
        let rawX = proxy.position(forX: week) ?? 0
        let rawY = proxy.position(forY: w) ?? 0
        let x = rawX + plot.minX
        let y = rawY + plot.minY

        // Vertical guide
        Path { p in
            p.move(to: CGPoint(x: x, y: plot.minY))
            p.addLine(to: CGPoint(x: x, y: plot.maxY))
        }
        .stroke(Theme.Palette.accent.opacity(0.4),
                style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

        // Pin: glow halo + outer ring + filled dot
        ZStack {
            Circle()
                .fill(Theme.Palette.accent.opacity(0.22))
                .frame(width: 28, height: 28)
            Circle()
                .stroke(Theme.Palette.bg, lineWidth: 2)
                .background(Circle().fill(Theme.Palette.accent))
                .frame(width: 14, height: 14)
        }
        .position(x: x, y: y)
        .contentShape(Circle().inset(by: -20))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let local = value.location.x - plot.minX
                    guard let raw: Int = proxy.value(atX: local, as: Int.self) else { return }
                    let clamped = max(0, min(xMax, raw))
                    if clamped != pinWeek {
                        pinWeek = clamped
                        Haptics.select()
                    }
                }
        )
        .animation(.interactiveSpring(response: 0.25), value: effectivePinWeek)
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
