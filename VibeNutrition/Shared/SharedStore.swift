import Foundation

/// Today's calorie + water state, shared from the app to the widgets via the
/// App Group. Pure value type encoded into the shared `UserDefaults` — the
/// widgets never touch Supabase, they only render whatever the app last wrote
/// (plus any optimistic water added straight from the widget button).
struct CalorieSnapshot: Codable, Equatable {
    var kcalConsumed: Int
    var kcalTarget: Int
    /// Millilitres of water logged today and the daily goal.
    var waterMl: Int
    var waterGoalMl: Int
    /// Local start-of-day this snapshot describes. Used to detect a stale
    /// snapshot left over from a previous day so the widget can zero out.
    var day: Date

    init(kcalConsumed: Int, kcalTarget: Int, waterMl: Int = 0,
         waterGoalMl: Int = 2000, day: Date) {
        self.kcalConsumed = kcalConsumed
        self.kcalTarget = kcalTarget
        self.waterMl = waterMl
        self.waterGoalMl = waterGoalMl
        self.day = day
    }

    // Tolerant decode: a snapshot written by an older app build won't have the
    // water keys. Default them instead of failing the whole decode (which would
    // blank the widget until the next app refresh).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kcalConsumed = try c.decode(Int.self, forKey: .kcalConsumed)
        kcalTarget = try c.decode(Int.self, forKey: .kcalTarget)
        waterMl = try c.decodeIfPresent(Int.self, forKey: .waterMl) ?? 0
        waterGoalMl = try c.decodeIfPresent(Int.self, forKey: .waterGoalMl) ?? 2000
        day = try c.decode(Date.self, forKey: .day)
    }

    var kcalRemaining: Int { max(0, kcalTarget - kcalConsumed) }
    var kcalOver: Int { max(0, kcalConsumed - kcalTarget) }
    var isOverTarget: Bool { kcalOver > 0 }

    /// 0…1.5 — mirrors `DashboardViewModel.kcalProgress` so the widget ring
    /// matches the in-app ring (allows up to 1.5 to show an "over" arc).
    var progress: Double {
        guard kcalTarget > 0 else { return 0 }
        return min(1.5, Double(kcalConsumed) / Double(kcalTarget))
    }

    /// 0…1 hydration progress for the widget gauge.
    var waterProgress: Double {
        guard waterGoalMl > 0 else { return 0 }
        return min(1, Double(waterMl) / Double(waterGoalMl))
    }

    /// Litres logged today, one decimal (e.g. "1.2").
    var waterLitresString: String { String(format: "%.1f", Double(waterMl) / 1000) }
    var waterGoalLitresString: String { String(format: "%.1f", Double(waterGoalMl) / 1000) }

    static let placeholder = CalorieSnapshot(
        kcalConsumed: 1240, kcalTarget: 2100, waterMl: 1250, waterGoalMl: 2000,
        day: Calendar.current.startOfDay(for: Date())
    )
}

/// Read/write bridge over the App Group `UserDefaults`. Compiled into both the
/// app target and the widget extension.
enum SharedStore {
    /// Must match the `com.apple.security.application-groups` entitlement on
    /// both the app and the widget extension.
    static let appGroupID = "group.com.vibecal.app"
    private static let snapshotKey = "calorieSnapshot"
    /// Queue of water amounts (ml) logged from the widget that haven't been
    /// persisted to Supabase yet. The app drains this on foreground.
    private static let pendingWaterKey = "pendingWaterMl"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func writeSnapshot(_ snapshot: CalorieSnapshot) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    /// Returns the stored snapshot, but only if it describes *today* — a
    /// snapshot from a previous day is reported as a fresh zeroed day so the
    /// widget never shows yesterday's totals before the app has refreshed.
    static func readSnapshot() -> CalorieSnapshot? {
        guard
            let data = defaults?.data(forKey: snapshotKey),
            let snapshot = try? JSONDecoder().decode(CalorieSnapshot.self, from: data)
        else { return nil }

        let today = Calendar.current.startOfDay(for: Date())
        guard snapshot.day == today else {
            return CalorieSnapshot(
                kcalConsumed: 0, kcalTarget: snapshot.kcalTarget,
                waterMl: 0, waterGoalMl: snapshot.waterGoalMl, day: today
            )
        }
        return snapshot
    }

    // MARK: - Water logged from the widget

    /// Optimistically adds `ml` to today's water in the shared snapshot and
    /// queues the amount for the app to persist later. Called from the widget's
    /// `LogWaterIntent`, where there's no network/Supabase access.
    static func addPendingWater(_ ml: Int) {
        let today = Calendar.current.startOfDay(for: Date())
        let current = readSnapshot()
            ?? CalorieSnapshot(kcalConsumed: 0, kcalTarget: 0, day: today)
        var updated = current
        updated.waterMl += ml
        writeSnapshot(updated)

        var queue = defaults?.array(forKey: pendingWaterKey) as? [Int] ?? []
        queue.append(ml)
        defaults?.set(queue, forKey: pendingWaterKey)
    }

    /// Returns and clears the pending water amounts. The app calls this on
    /// foreground and writes each amount to Supabase.
    static func drainPendingWater() -> [Int] {
        let queue = defaults?.array(forKey: pendingWaterKey) as? [Int] ?? []
        if !queue.isEmpty { defaults?.removeObject(forKey: pendingWaterKey) }
        return queue
    }
}

/// Deep links the widgets fire. The app intercepts these in `onOpenURL`.
enum WidgetDeepLink {
    static let scheme = "vibecal"
    /// Opens the app and launches the camera scan flow.
    static let scan = URL(string: "\(scheme)://scan")!
}
