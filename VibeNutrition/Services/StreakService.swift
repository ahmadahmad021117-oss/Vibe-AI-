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
        // Pull last ~45 days of log timestamps once; compute locally.
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

        let cal = Calendar.current
        let loggedDays: Set<Date> = Set(rows.map { cal.startOfDay(for: $0.logged_at) })

        var streak = 0
        var cursor = cal.startOfDay(for: Date())
        while loggedDays.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }
}
