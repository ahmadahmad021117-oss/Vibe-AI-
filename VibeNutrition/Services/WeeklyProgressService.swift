import Foundation
import Supabase

@MainActor
final class WeeklyProgressService {
    static let shared = WeeklyProgressService()
    private init() {}

    struct Summary: Codable, Hashable {
        let days: Int
        let logCount: Int
        let avgKcal: Int
        let avgProteinG: Int
        let targetKcal: Int
        let adherencePct: Int
        let weightStartKg: Double?
        let weightEndKg: Double?
        let actualDeltaKg: Double?
        let expectedDeltaKg: Double?
        let adaptiveNudge: Bool

        enum CodingKeys: String, CodingKey {
            case days
            case logCount = "log_count"
            case avgKcal = "avg_kcal"
            case avgProteinG = "avg_protein_g"
            case targetKcal = "target_kcal"
            case adherencePct = "adherence_pct"
            case weightStartKg = "weight_start_kg"
            case weightEndKg = "weight_end_kg"
            case actualDeltaKg = "actual_delta_kg"
            case expectedDeltaKg = "expected_delta_kg"
            case adaptiveNudge = "adaptive_nudge"
        }
    }

    func fetch() async throws -> Summary {
        try await SupabaseService.shared.functions.invoke(
            "weekly-progress",
            options: FunctionInvokeOptions(body: [:] as [String: String])
        )
    }
}
