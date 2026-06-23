import SwiftUI
import Charts

/// 7-day calorie history with goal-aware bar coloring.
///
/// "Above target" isn't universally bad: a person bulking *wants* a surplus,
/// a person cutting wants a deficit. This chart colors each bar relative to
/// the user's goal direction so the visual matches "are you on plan today?"
/// instead of "did you exceed the number?".
struct CalorieWeekChart: View {
    /// Oldest → newest. Empty days are zero-kcal entries so the bar slot still renders.
    let history: [FoodLogService.DailyKcal]
    let targetKcal: Int
    /// nil → treat as flat / maintain (balanced coloring around the target).
    let direction: GoalType.Direction?

    /// Live scrub position from the chart gesture. Chart resets this to nil the
    /// moment the finger lifts — we mirror it into `pinnedDate` so the highlight
    /// survives the release.
    @State private var selectedDate: Date?

    /// The day that stays highlighted after you lift your finger. Tapping or
    /// dragging onto another day moves the pin; it persists until then.
    @State private var pinnedDate: Date?

    /// The currently-pinned day, snapped to the nearest real bar.
    private var selectedDay: FoodLogService.DailyKcal? {
        guard let pinnedDate else { return nil }
        return nearestDay(to: pinnedDate)
    }

    private func nearestDay(to date: Date) -> FoodLogService.DailyKcal? {
        history.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
    }

    /// What counts as "on target" for the given goal direction.
    enum DayStatus {
        case noData
        case onTarget   // green
        case caution    // amber (within ±10% in maintain, or under by ≤10% when bulking, etc.)
        case offTarget  // red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            header
            chart
                .frame(height: 140)
            legend
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
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Calorie history")
                    .font(Theme.Typo.h3)
                    .foregroundStyle(Theme.Palette.text)
                Text("Last 7 days vs target")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            Spacer()
            onTargetBadge
        }
    }

    private var onTargetBadge: some View {
        let onTargetCount = history.filter { status(for: $0).isOnTarget }.count
        let loggedCount = history.filter { $0.kcal > 0 }.count
        return HStack(spacing: 4) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 11, weight: .bold))
            Text("\(onTargetCount)/\(max(loggedCount, history.count)) on target")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(Theme.Palette.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Theme.Palette.accent.opacity(0.15), in: Capsule())
    }

    private var chart: some View {
        Chart {
            // Target line so the user can see the bars against the daily goal.
            // No inline annotation — the value already shows on the left y-axis
            // tick, and a floating "Target 2,000" label kept colliding with the
            // tallest bar at this card height.
            RuleMark(y: .value("Target", targetKcal))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Theme.Palette.textMuted.opacity(0.7))

            ForEach(history) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Kcal", day.kcal),
                    width: .ratio(0.6)
                )
                .foregroundStyle(color(for: status(for: day)))
                .cornerRadius(4)
                // Dim the other bars while scrubbing so the selected day pops.
                .opacity(selectedDay == nil || selectedDay?.id == day.id ? 1 : 0.35)
            }

            // Tooltip pinned to the day being scrubbed.
            if let selectedDay {
                RuleMark(x: .value("Selected", selectedDay.date, unit: .day))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Theme.Palette.textMuted.opacity(0.25))
                    .annotation(
                        position: .top,
                        spacing: 6,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        tooltip(for: selectedDay)
                    }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartYScale(domain: 0...yAxisMax)
        .chartXAxis {
            AxisMarks(values: history.map(\.date)) { value in
                AxisValueLabel {
                    if let d = value.as(Date.self) {
                        Text(Self.dayLabel.string(from: d))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.Palette.textMuted)
                    }
                }
            }
        }
        .chartYAxis {
            // Two reference lines (0 + target) keep the axis quiet — anything
            // denser fights the bars at this height.
            AxisMarks(position: .leading, values: [0, targetKcal]) { value in
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text(v.grouped)
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.Palette.textDim)
                    }
                }
                AxisGridLine().foregroundStyle(Theme.Palette.border.opacity(0.5))
            }
        }
        .accessibilityLabel("7-day calorie history vs target \(targetKcal) kilocalories")
        // Mirror the live gesture into the persistent pin so the selection stays
        // put after release; only move (and buzz) when the day actually changes.
        .onChange(of: selectedDate) { _, newValue in
            guard let newValue, let day = nearestDay(to: newValue) else { return }
            if pinnedDate != day.date {
                pinnedDate = day.date
                Haptics.select()
            }
        }
    }

    /// Floating label shown above the scrubbed bar: weekday + what was eaten.
    private func tooltip(for day: FoodLogService.DailyKcal) -> some View {
        VStack(spacing: 1) {
            Text(Self.tooltipDayLabel.string(from: day.date))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.Palette.textMuted)
            Text(day.kcal > 0 ? "\(day.kcal.grouped) kcal" : "No food logged")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Palette.text)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.Palette.bgElevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.Palette.border, lineWidth: 1)
        )
        .fixedSize()
    }

    private var legend: some View {
        HStack(spacing: Theme.Spacing.md) {
            legendDot(color: Theme.Palette.success, label: "On target")
            legendDot(color: Theme.Palette.warning, label: "Close")
            legendDot(color: Theme.Palette.danger, label: "Off target")
            Spacer()
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.Palette.textMuted)
        }
    }

    // MARK: - Status logic

    /// Score one day against the target given the user's goal direction.
    ///
    /// Tolerance is the same ±10% band in all directions: small daily noise
    /// shouldn't tip a user from "on target" to "off target". The *side* of
    /// the band that's bad changes with the goal.
    private func status(for day: FoodLogService.DailyKcal) -> DayStatus {
        guard day.kcal > 0, targetKcal > 0 else { return .noData }
        let ratio = Double(day.kcal) / Double(targetKcal)
        switch direction ?? .flat {
        case .down:
            // Loser: under or at target is good. Just over is caution. Well over is bad.
            if ratio <= 1.0 { return .onTarget }
            if ratio <= 1.10 { return .caution }
            return .offTarget
        case .up:
            // Gainer: at/above target is good. Just under is caution. Well under is bad.
            if ratio >= 1.0 { return .onTarget }
            if ratio >= 0.90 { return .caution }
            return .offTarget
        case .flat:
            // Maintain: ±10% band is the sweet spot, drift further → caution → off.
            if abs(ratio - 1.0) <= 0.10 { return .onTarget }
            if abs(ratio - 1.0) <= 0.20 { return .caution }
            return .offTarget
        }
    }

    private func color(for status: DayStatus) -> Color {
        switch status {
        case .noData:    return Theme.Palette.border
        case .onTarget:  return Theme.Palette.success
        case .caution:   return Theme.Palette.warning
        case .offTarget: return Theme.Palette.danger
        }
    }

    /// Pad the Y domain a bit above whichever is larger — the target or the max consumed day —
    /// so the tallest bar doesn't slam into the top edge of the chart.
    private var yAxisMax: Int {
        let peak = history.map(\.kcal).max() ?? 0
        let base = max(targetKcal, peak)
        return max(100, Int(Double(base) * 1.15))
    }

    private static let dayLabel: DateFormatter = {
        // "EEEEE" → narrow weekday symbol (single letter: M, T, W, T, F, S, S).
        // Plain "EEE" produced 3-letter labels that crowded each other under
        // 7 bars on a phone-width chart.
        let f = DateFormatter()
        f.dateFormat = "EEEEE"
        return f
    }()

    /// Fuller label for the scrub tooltip, e.g. "Mon, Jun 16".
    private static let tooltipDayLabel: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEMMMd")
        return f
    }()
}

private extension CalorieWeekChart.DayStatus {
    var isOnTarget: Bool { self == .onTarget }
}

#Preview {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let sample: [FoodLogService.DailyKcal] = (0..<7).reversed().map { offset in
        let date = cal.date(byAdding: .day, value: -offset, to: today) ?? today
        let kcal = [1850, 2100, 1650, 0, 2300, 1900, 1750][offset]
        return .init(date: date, kcal: kcal)
    }
    return VStack(spacing: 16) {
        CalorieWeekChart(history: sample, targetKcal: 2000, direction: .down)
        CalorieWeekChart(history: sample, targetKcal: 2000, direction: .up)
    }
    .padding()
    .background(Theme.Palette.bg)
    .preferredColorScheme(.dark)
}
