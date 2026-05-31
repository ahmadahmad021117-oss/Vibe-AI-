import Foundation

/// Today's calorie state, shared from the app to the widgets via the App Group.
/// Pure value type encoded into the shared `UserDefaults` — the widgets never
/// touch Supabase, they only render whatever the app last wrote.
struct CalorieSnapshot: Codable, Equatable {
    var kcalConsumed: Int
    var kcalTarget: Int
    /// Local start-of-day this snapshot describes. Used to detect a stale
    /// snapshot left over from a previous day so the widget can zero out.
    var day: Date

    var kcalRemaining: Int { max(0, kcalTarget - kcalConsumed) }
    var kcalOver: Int { max(0, kcalConsumed - kcalTarget) }
    var isOverTarget: Bool { kcalOver > 0 }

    /// 0…1.5 — mirrors `DashboardViewModel.kcalProgress` so the widget ring
    /// matches the in-app ring (allows up to 1.5 to show an "over" arc).
    var progress: Double {
        guard kcalTarget > 0 else { return 0 }
        return min(1.5, Double(kcalConsumed) / Double(kcalTarget))
    }

    static let placeholder = CalorieSnapshot(
        kcalConsumed: 1240, kcalTarget: 2100, day: Calendar.current.startOfDay(for: Date())
    )
}

/// Read/write bridge over the App Group `UserDefaults`. Compiled into both the
/// app target and the widget extension.
enum SharedStore {
    /// Must match the `com.apple.security.application-groups` entitlement on
    /// both the app and the widget extension.
    static let appGroupID = "group.com.vibecal.app"
    private static let snapshotKey = "calorieSnapshot"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func writeSnapshot(_ snapshot: CalorieSnapshot) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    /// Returns the stored snapshot, but only if it describes *today* — a
    /// snapshot from a previous day is reported as a fresh zeroed day so the
    /// widget never shows yesterday's total before the app has refreshed.
    static func readSnapshot() -> CalorieSnapshot? {
        guard
            let data = defaults?.data(forKey: snapshotKey),
            let snapshot = try? JSONDecoder().decode(CalorieSnapshot.self, from: data)
        else { return nil }

        let today = Calendar.current.startOfDay(for: Date())
        guard snapshot.day == today else {
            return CalorieSnapshot(kcalConsumed: 0, kcalTarget: snapshot.kcalTarget, day: today)
        }
        return snapshot
    }
}

/// Deep links the widgets fire. The app intercepts these in `onOpenURL`.
enum WidgetDeepLink {
    static let scheme = "vibecal"
    /// Opens the app and launches the camera scan flow.
    static let scan = URL(string: "\(scheme)://scan")!
}
