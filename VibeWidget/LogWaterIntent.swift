import AppIntents
import WidgetKit

/// Interactive widget action: logs a glass of water without opening the app.
/// Runs in the widget extension process, so it can't reach Supabase — it writes
/// an optimistic delta into the shared App Group store and queues the amount for
/// the app to persist on next foreground. WidgetKit reloads the timeline when
/// `perform()` returns, so the gauge updates immediately.
struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log water"
    static var description = IntentDescription("Adds water to today's total.")

    @Parameter(title: "Amount (ml)")
    var amountMl: Int

    init() { amountMl = 250 }
    init(amountMl: Int) { self.amountMl = amountMl }

    func perform() async throws -> some IntentResult {
        SharedStore.addPendingWater(amountMl)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
