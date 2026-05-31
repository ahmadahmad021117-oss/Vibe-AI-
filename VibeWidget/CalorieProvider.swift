import WidgetKit

/// Single entry the timeline carries: the calorie snapshot the app last wrote.
struct CalorieEntry: TimelineEntry {
    let date: Date
    let snapshot: CalorieSnapshot
}

/// Reads the shared snapshot. Widgets are static between app refreshes, so a
/// one-entry timeline is enough — the app pokes `WidgetCenter.reloadAllTimelines()`
/// whenever the data changes, and we also refresh at the next local midnight so
/// the count resets even if the app never opens.
struct CalorieProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalorieEntry {
        CalorieEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (CalorieEntry) -> Void) {
        let snapshot = context.isPreview ? .placeholder : (SharedStore.readSnapshot() ?? .placeholder)
        completion(CalorieEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalorieEntry>) -> Void) {
        let now = Date()
        let snapshot = SharedStore.readSnapshot()
            ?? CalorieSnapshot(kcalConsumed: 0, kcalTarget: 0, day: Calendar.current.startOfDay(for: now))
        let entry = CalorieEntry(date: now, snapshot: snapshot)

        let nextMidnight = Calendar.current.nextDate(
            after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(3600)

        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}
