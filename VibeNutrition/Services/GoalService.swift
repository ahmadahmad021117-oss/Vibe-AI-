import Foundation
import Supabase

@MainActor
final class GoalService {
    static let shared = GoalService()
    private init() {}

    func upsertActiveGoal(type: GoalType, startWeightKg: Double, goalWeightKg: Double) async throws {
        guard let userId = AuthService.shared.userId else { return }
        let payload: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "type": .string(type.rawValue),
            "start_weight_kg": .double(startWeightKg),
            "goal_weight_kg": .double(goalWeightKg),
        ]
        try await SupabaseService.shared.from("goals").insert(payload).execute()
    }

    func fetchLatest() async throws -> Goal? {
        guard let userId = AuthService.shared.userId else { return nil }
        let rows: [Goal] = try await SupabaseService.shared
            .from("goals")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first
    }
}
