import SwiftUI
import WidgetKit

/// Home-screen square widget: today's calorie ring. Tapping anywhere opens the
/// app straight into the camera scan flow.
struct CalorieWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CalorieWidget", provider: CalorieProvider()) { entry in
            CalorieWidgetView(snapshot: entry.snapshot)
                .containerBackground(WColor.bg, for: .widget)
        }
        .configurationDisplayName("Calories Today")
        .description("See calories left and tap to snap a meal.")
        .supportedFamilies([.systemSmall])
    }
}

private struct CalorieWidgetView: View {
    let snapshot: CalorieSnapshot

    var body: some View {
        ZStack {
            ring
            centerLabel
        }
        .padding(4)
        .widgetURL(WidgetDeepLink.scan)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(WColor.track, style: StrokeStyle(lineWidth: 12, lineCap: .round))

            Circle()
                .trim(from: 0, to: min(1, snapshot.progress))
                .stroke(
                    snapshot.isOverTarget ? AnyShapeStyle(WColor.warning) : AnyShapeStyle(WColor.accentGradient),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Over-target overlay arc, mirrors the in-app ring behaviour.
            if snapshot.isOverTarget {
                Circle()
                    .trim(from: 0, to: min(0.5, snapshot.progress - 1))
                    .stroke(WColor.warning, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
    }

    private var centerLabel: some View {
        VStack(spacing: 1) {
            if snapshot.kcalTarget == 0 {
                Image(systemName: "camera.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(WColor.accent)
                Text("Tap to log")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WColor.textMuted)
            } else if snapshot.isOverTarget {
                Text("\(snapshot.kcalOver)")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(WColor.warning)
                Text("over")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WColor.textMuted)
            } else {
                Text("\(snapshot.kcalRemaining)")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(WColor.text)
                Text("kcal left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WColor.textMuted)
            }
        }
    }
}
