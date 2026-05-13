import Foundation
import Supabase

@MainActor
final class StreakService {
    static let shared = StreakService()
    private init() {}

    /// Maximum streak we'll attempt to count. Bounds the iterative walk-back so a
    /// timezone-induced edge case can never produce a runaway loop.
    static let maxStreakDays = 365

    /// Count consecutive days (working back from today) that have at least one food_log entry.
    /// Today counts toward the streak only if at least one log exists today.
    ///
    /// Day boundaries are anchored in the device's *current* calendar/timezone. Logs are
    /// absolute `Date` values, so if the user crosses timezones the mapping of timestamp
    /// → local day shifts automatically. DST transitions are handled correctly because
    /// `Calendar.date(byAdding: .day, ...)` walks *wall-clock* days, not 24-hour blocks.
    func currentStreak() async throws -> Int {
        guard let userId = AuthService.shared.userId else { return 0 }
        // Snapshot once so a timezone change mid-call can't desync cutoff and computeStreak.
        let calendar = Calendar.current
        let now = Date()
        guard let cutoff = calendar.date(byAdding: .day, value: -Self.maxStreakDays, to: now) else { return 0 }
        let iso = ISO8601DateFormatter().string(from: cutoff)

        struct Row: Decodable { let logged_at: Date }
        let rows: [Row] = try await SupabaseService.shared
            .from("food_logs")
            .select("logged_at")
            .eq("user_id", value: userId.uuidString)
            .gte("logged_at", value: iso)
            .execute()
            .value

        return Self.computeStreak(loggedAt: rows.map { $0.logged_at }, now: now, calendar: calendar)
    }

    /// Pure helper, exposed for testing.
    /// Counts consecutive days back from `now` that appear in the input timestamps.
    /// Capped at `maxStreakDays` as a defensive bound.
    nonisolated static func computeStreak(loggedAt: [Date], now: Date, calendar: Calendar) -> Int {
        let loggedDays = Set(loggedAt.map { calendar.startOfDay(for: $0) })
        var streak = 0
        var cursor = calendar.startOfDay(for: now)
        while loggedDays.contains(cursor) && streak < maxStreakDays {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }
}
