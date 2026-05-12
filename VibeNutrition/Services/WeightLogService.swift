import Foundation
import Supabase

@MainActor
final class WeightLogService {
    static let shared = WeightLogService()
    private init() {}

    func write(weightKg: Double) async throws {
        guard let userId = AuthService.shared.userId else { return }
        let payload: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "weight_kg": .double(weightKg),
        ]
        try await SupabaseService.shared.from("weight_logs").insert(payload).execute()
    }

    func fetchLatest() async throws -> WeightLog? {
        guard let userId = AuthService.shared.userId else { return nil }
        let rows: [WeightLog] = try await SupabaseService.shared
            .from("weight_logs")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("logged_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func fetchRecent(days: Int = 30) async throws -> [WeightLog] {
        guard let userId = AuthService.shared.userId else { return [] }
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return [] }
        let iso = ISO8601DateFormatter().string(from: cutoff)
        return try await SupabaseService.shared
            .from("weight_logs")
            .select()
            .eq("user_id", value: userId.uuidString)
            .gte("logged_at", value: iso)
            .order("logged_at", ascending: true)
            .execute()
            .value
    }
}
