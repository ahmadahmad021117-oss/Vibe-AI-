import Foundation
import Supabase

@MainActor
final class TargetService {
    static let shared = TargetService()
    private init() {}

    func writeLatest(_ result: NutritionEngine.Result, inputs: NutritionEngine.Inputs) async throws {
        guard let userId = AuthService.shared.userId else { return }

        let inputsJSON: [String: AnyJSON] = [
            "sex": .string(inputs.sex.rawValue),
            "age": .integer(inputs.age),
            "height_cm": .double(inputs.heightCm),
            "weight_kg": .double(inputs.weightKg),
            "training_days_per_week": .integer(inputs.trainingDaysPerWeek),
            "avg_steps": inputs.avgSteps.map { AnyJSON.integer($0) } ?? .null,
            "goal": .string(inputs.goal.rawValue),
            "main_focus": inputs.mainFocus.map { AnyJSON.string($0.rawValue) } ?? .null,
            "bmr": .integer(result.bmr),
            "activity_multiplier": .double(result.activityMultiplier),
            "tdee": .integer(result.tdee),
            "weekly_delta_kg": .double(result.weeklyDeltaKg),
        ]

        let payload: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "kcal": .integer(result.kcalTarget),
            "protein_g": .integer(result.proteinG),
            "carbs_g": .integer(result.carbsG),
            "fat_g": .integer(result.fatG),
            "inputs_json": .object(inputsJSON),
        ]

        try await SupabaseService.shared.from("targets").insert(payload).execute()
    }

    func fetchLatest() async throws -> NutritionTarget? {
        guard let userId = AuthService.shared.userId else { return nil }
        let rows: [NutritionTarget] = try await SupabaseService.shared
            .from("targets")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("computed_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first
    }
}
