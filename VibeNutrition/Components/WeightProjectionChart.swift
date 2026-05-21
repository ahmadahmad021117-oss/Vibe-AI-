import SwiftUI
import Charts

/// Lightweight chart that projects a user's weight trajectory from `currentKg` toward `goalKg`
/// at the selected `pace`. Reused in onboarding (pace step) and on the dashboard.
///
/// The X domain is pinned to the actual data range so the line always spans the chart, regardless
/// of which pace the user picks. The Y domain is padded so the line never hugs the edges.
///
/// Users can drag the pin along the projection line — the tooltip reports the projected weight
/// and ETA date at that exact week. Pin snaps to whole weeks; a haptic fires on each snap.
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

    private var goalDateText: String? {
        guard weeks > 0, let last = points.last else { return nil }
        return Self.dateFormatter.string(from: last.date)
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

    /// The week the pin currently sits on. Defaults to the goal week (end of projection)
    /// so the user always sees a visible pin to grab.
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
                .frame(height: 220)
                // No .clipped() — the tooltip needs to escape the chart frame when the pin
                // is near the top of the line, otherwise the bubble gets cut off.
                .accessibilityLabel("Weight projection chart. Drag the pin to scrub through weeks.")
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
        // Pace change resets pin to the new goal week so the user can scrub from scratch.
        .onChange(of: pace) { _, _ in pinWeek = nil }
        // Animate only the data, not the container, to avoid layout jitter.
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

            // Static start marker (always at week 0)
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
        .chartOverlay { proxy in
            GeometryReader { geo in
                pinOverlay(proxy: proxy, geo: geo)
            }
        }
    }

    /// Draggable pin layer: vertical guide line, large hit-target circle, and a floating
    /// tooltip with the projected weight and ETA at the scrubbed week.
    @ViewBuilder
    private func pinOverlay(proxy: ChartProxy, geo: GeometryProxy) -> some View {
        // plotFrame is the iOS 17+ replacement for plotAreaFrame; returns nil only if the
        // chart hasn't laid out yet.
        let plot: CGRect = {
            if let anchor = proxy.plotFrame { return geo[anchor] }
            return .zero
        }()
        let week = effectivePinWeek
        let w = weight(atWeek: week)
        // position(forX:) / forY can return nil if the value is outside the domain.
        let rawX = proxy.position(forX: week) ?? 0
        let rawY = proxy.position(forY: w) ?? 0
        // Convert from plot-area-local to overlay-local coordinates.
        let x = rawX + plot.minX
        let y = rawY + plot.minY

        // Vertical guide
        Path { p in
            p.move(to: CGPoint(x: x, y: plot.minY))
            p.addLine(to: CGPoint(x: x, y: plot.maxY))
        }
        .stroke(Theme.Palette.accent.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

        // Floating tooltip — flips below the pin when the pin is near the top of the chart
        // so the bubble never gets clipped by the chart frame or the section above it.
        tooltip(week: week, weight: w)
            .background(
                GeometryReader { tg in
                    Color.clear.preference(key: TooltipSizeKey.self, value: tg.size)
                }
            )
            .modifier(
                TooltipPositioner(
                    pinX: x,
                    pinY: y,
                    plot: plot
                )
            )

        // Pin: glow halo + outer ring + filled dot
        ZStack {
            Circle()
                .fill(Theme.Palette.accent.opacity(0.22))
                .frame(width: 32, height: 32)
            Circle()
                .stroke(Theme.Palette.bg, lineWidth: 2)
                .background(Circle().fill(Theme.Palette.accent))
                .frame(width: 16, height: 16)
        }
        .position(x: x, y: y)
        // Larger invisible hit target so dragging is forgiving.
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

    private func tooltip(week: Int, weight: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Self.dateFormatter.string(from: date(atWeek: week)))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.Palette.textMuted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(String(format: "%.1f", weight))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Palette.text)
                    .contentTransition(.numericText(value: weight))
                Text("kg")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            Text(weekSubtitle(week))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.Palette.textDim)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.Palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.Palette.accent.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
    }

    private func weekSubtitle(_ week: Int) -> String {
        if week == 0 { return "Now" }
        if week == xMax { return "Goal" }
        let months = Double(week) / 4.345
        if week <= 12 { return "Week \(week)" }
        return String(format: "%.1f months", months)
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

// MARK: - Tooltip positioning

/// Reports the rendered tooltip size so we can keep it from clipping past the plot edges.
private struct TooltipSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

/// Positions the tooltip above the pin by default, flipping to BELOW the pin when the pin
/// sits in the upper portion of the plot — that way the bubble never overflows the chart
/// frame even when there's no room above. Horizontal position is clamped inside the plot.
private struct TooltipPositioner: ViewModifier {
    let pinX: CGFloat
    let pinY: CGFloat
    let plot: CGRect

    /// Vertical gap between the pin and the tooltip's nearest edge.
    private let gap: CGFloat = 16

    @State private var size: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(TooltipSizeKey.self) { size = $0 }
            .position(x: clampedX, y: tooltipY)
    }

    private var clampedX: CGFloat {
        let half = size.width / 2
        let minCenter = plot.minX + half + 4
        let maxCenter = plot.maxX - half - 4
        return min(max(pinX, minCenter), maxCenter)
    }

    /// Returns the y-center for the tooltip. Prefers above; flips below when above would
    /// clip past the chart's top edge.
    private var tooltipY: CGFloat {
        let halfH = size.height / 2
        let aboveCenter = pinY - gap - halfH
        let belowCenter = pinY + gap + halfH

        // Above fits if its top edge stays at or below plot.minY (with a tiny overflow allowance).
        if aboveCenter - halfH >= plot.minY - 4 {
            return aboveCenter
        }
        // Otherwise try below if it doesn't run off the bottom edge.
        if belowCenter + halfH <= plot.maxY + 4 {
            return belowCenter
        }
        // Last-resort: pin to top edge.
        return plot.minY + halfH + 4
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
