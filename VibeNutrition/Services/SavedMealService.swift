import Foundation
import Supabase

/// Backs the "meal registry": meals the user saves from the Meal Ideas card.
@MainActor
final class SavedMealService {
    static let shared = SavedMealService()
    private init() {}

    private var notSignedIn: NSError {
        NSError(
            domain: "SavedMealService", code: -1,
            userInfo: [NSLocalizedDescriptionKey: String(
                localized: "saved_meal.error.not_signed_in",
                defaultValue: "Not signed in.",
                comment: "Shown when attempting to use the meal registry without an authenticated user"
            )]
        )
    }

    func list() async throws -> [SavedMeal] {
        guard let userId = AuthService.shared.userId else { return [] }
        let rows: [SavedMeal] = try await SupabaseService.shared
            .from("saved_meals")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows
    }

    @discardableResult
    func save(name: String, description: String, kcal: Int,
              proteinG: Double, carbsG: Double, fatG: Double) async throws -> UUID {
        guard let userId = AuthService.shared.userId else { throw notSignedIn }
        let id = UUID()
        let payload: [String: AnyJSON] = [
            "id": .string(id.uuidString),
            "user_id": .string(userId.uuidString),
            "name": .string(name),
            "description": .string(description),
            "kcal": .integer(kcal),
            "protein_g": .double(proteinG),
            "carbs_g": .double(carbsG),
            "fat_g": .double(fatG),
        ]
        try await SupabaseService.shared.from("saved_meals").insert(payload).execute()
        return id
    }

    func delete(id: UUID) async throws {
        try await SupabaseService.shared.from("saved_meals")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    /// Whether a meal with this exact name is already in the registry — used to
    /// reflect a "Saved" state in the detail view without inserting a duplicate.
    func isSaved(name: String) async -> Bool {
        guard let userId = AuthService.shared.userId else { return false }
        do {
            let rows: [SavedMeal] = try await SupabaseService.shared
                .from("saved_meals")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("name", value: name)
                .limit(1)
                .execute()
                .value
            return !rows.isEmpty
        } catch {
            return false
        }
    }
}
