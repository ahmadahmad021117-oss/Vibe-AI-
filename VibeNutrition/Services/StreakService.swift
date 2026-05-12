import Foundation
import Supabase

@MainActor
final class StreakService {
    static let shared = StreakService()
    private init() {}

    /// Count consecutive days (working back from today) that have at least one food_log entry.
    /// Today counts toward the streak only if at least one log exists today.
    func currentStreak() async throws -> Int {
        guard let userId = AuthService.shared.userId else { return 0 }
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -45, to: Date()) else { return 0 }
        let iso = ISO8601DateFormatter().string(from: cutoff)

        struct Row: Decodable { let logged_at: Date }
        let rows: [Row] = try await SupabaseService.shared
            .from("food_logs")
            .select("logged_at")
            .eq("user_id", value: userId.uuidString)
            .gte("logged_at", value: iso)
            .execute()
            .value

        return Self.computeStreak(loggedAt: rows.map { $0.logged_at }, now: Date(), calendar: .current)
    }

    /// Pure helper, exposed for testing.
    /// Counts consecutive days back from `now` that appear in the input timestamps.
    static func computeStreak(loggedAt: [Date], now: Date, calendar: Calendar) -> Int {
        let loggedDays = Set(loggedAt.map { calendar.startOfDay(for: $0) })
        var streak = 0
        var cursor = calendar.startOfDay(for: now)
        while loggedDays.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }
}
