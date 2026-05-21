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

    /// Insert a new goal row reusing the existing start weight but with a new target.
    /// Re-infers `GoalType` from the actual current ↔ new-target delta so a user who
    /// originally onboarded as "Lose" can flip to "Gain" the moment they raise their
    /// target above their current weight. Preserves explicit choices (.buildMuscle /
    /// .recomp / .improveHealth) when the direction still matches.
    func updateGoalWeight(_ goalWeightKg: Double) async throws {
        guard let latest = try await fetchLatest() else { return }
        let currentKg = (try? await WeightLogService.shared.fetchLatest())?.weightKg
            ?? latest.startWeightKg
        let resolvedType = Self.resolveGoalType(
            existing: latest.type,
            currentKg: currentKg,
            goalKg: goalWeightKg
        )
        try await upsertActiveGoal(
            type: resolvedType,
            startWeightKg: latest.startWeightKg,
            goalWeightKg: goalWeightKg
        )
    }

    /// Pure helper so it's directly unit-testable. nonisolated because there's no actor state.
    nonisolated static func resolveGoalType(existing: GoalType, currentKg: Double, goalKg: Double) -> GoalType {
        let delta = goalKg - currentKg

        // Within 0.5 kg of current → maintenance. Preserve explicit recomp/improveHealth.
        if abs(delta) < 0.5 {
            switch existing {
            case .recomp:        return .recomp
            case .improveHealth: return .improveHealth
            default:             return .maintain
            }
        }

        if delta < 0 {
            // User wants to lose. Preserve recomp (mild cut); otherwise → loseWeight.
            return existing == .recomp ? .recomp : .loseWeight
        }

        // delta > 0: user wants to gain. Preserve buildMuscle if it was the explicit choice.
        return existing == .buildMuscle ? .buildMuscle : .gainWeight
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
