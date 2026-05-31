import SwiftUI
import WidgetKit

/// Quick-log widget.
///   * Accessory families (lock screen): a compact calorie gauge with the
///     water total; tapping opens the camera.
///   * systemSmall (home screen): calories left, a water progress bar, and an
///     interactive "+250 ml" button that logs water without opening the app.
struct QuickLogWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickLogWidget", provider: CalorieProvider()) { entry in
            QuickLogView(snapshot: entry.snapshot)
                .containerBackground(WColor.bg, for: .widget)
        }
        .configurationDisplayName("Quick Log")
        .description("Track water with one tap and snap a meal to log calories.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .systemSmall])
    }
}

private struct QuickLogView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: CalorieSnapshot

    var body: some View {
        switch family {
        case .systemSmall:
            small
        case .accessoryRectangular:
            rectangular.widgetURL(WidgetDeepLink.scan)
        default:
            circular.widgetURL(WidgetDeepLink.scan)
        }
    }

    // MARK: - Home screen (interactive)

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Calories — tapping this region opens the scan flow.
            Link(destination: WidgetDeepLink.scan) {
                HStack(spacing: 6) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(WColor.accent)
                    if snapshot.kcalTarget == 0 {
                        Text("Tap to log")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(WColor.text)
                    } else if snapshot.isOverTarget {
                        Text("\(snapshot.kcalOver) over")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(WColor.warning)
                    } else {
                        Text("\(snapshot.kcalRemaining)")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(WColor.text)
                        Text("kcal")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(WColor.textMuted)
                    }
                }
            }

            Spacer(minLength: 0)

            // Water progress.
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WColor.accentDeep)
                    Text("\(snapshot.waterLitresString) / \(snapshot.waterGoalLitresString) L")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(WColor.text)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(WColor.track)
                        Capsule().fill(WColor.accentDeep)
                            .frame(width: snapshot.waterProgress * proxy.size.width)
                    }
                }
                .frame(height: 6)
            }

            // Interactive: log a glass without opening the app.
            Button(intent: LogWaterIntent(amountMl: 250)) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("250 ml")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(WColor.accentDeep)
                .frame(maxWidth: .infinity, minHeight: 28)
                .background(WColor.accentDeep.opacity(0.15), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Lock screen

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if snapshot.kcalTarget == 0 {
                Image(systemName: "camera.fill").font(.system(size: 18, weight: .bold))
            } else {
                Gauge(value: min(1, snapshot.progress)) {
                    Image(systemName: "fork.knife")
                } currentValueLabel: {
                    Text("\(snapshot.kcalRemaining)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .gaugeStyle(.accessoryCircularCapacity)
            }
        }
    }

    private var rectangular: some View {
        HStack(spacing: 8) {
            Image(systemName: "camera.fill")
                .font(.system(size: 22, weight: .bold))
            VStack(alignment: .leading, spacing: 1) {
                if snapshot.kcalTarget == 0 {
                    Text("Log a meal").font(.system(size: 15, weight: .semibold))
                    Text("Tap to scan").font(.system(size: 12))
                } else {
                    Text("\(snapshot.kcalRemaining) kcal left")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Water \(snapshot.waterLitresString) / \(snapshot.waterGoalLitresString) L")
                        .font(.system(size: 12))
                }
            }
            Spacer(minLength: 0)
        }
    }
}
