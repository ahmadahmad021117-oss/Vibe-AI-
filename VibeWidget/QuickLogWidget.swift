import SwiftUI
import WidgetKit

/// Lock-screen widget for fast logging. Circular shows a calorie gauge;
/// rectangular shows the running total. Tapping either opens the camera.
struct QuickLogWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickLogWidget", provider: CalorieProvider()) { entry in
            QuickLogView(snapshot: entry.snapshot)
                .widgetURL(WidgetDeepLink.scan)
        }
        .configurationDisplayName("Quick Log")
        .description("Tap to snap a meal and log calories.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

private struct QuickLogView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: CalorieSnapshot

    var body: some View {
        switch family {
        case .accessoryRectangular:
            rectangular
        default:
            circular
        }
    }

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
                    Text("\(snapshot.kcalConsumed) / \(snapshot.kcalTarget) · tap to log")
                        .font(.system(size: 12))
                }
            }
            Spacer(minLength: 0)
        }
    }
}
