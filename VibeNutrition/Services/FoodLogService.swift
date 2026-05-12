import Foundation
import Supabase

@MainActor
final class FoodLogService {
    static let shared = FoodLogService()
    private init() {}

    func write(items: [FoodItem], imagePath: String?, source: LogSource) async throws {
        guard let userId = AuthService.shared.userId else { return }

        let kcal = items.reduce(0) { $0 + $1.kcal }
        let protein = items.reduce(0) { $0 + $1.proteinG }
        let carbs = items.reduce(0) { $0 + $1.carbsG }
        let fat = items.reduce(0) { $0 + $1.fatG }

        let itemsJSON: [AnyJSON] = items.map { item in
            var d: [String: AnyJSON] = [
                "name": .string(item.name),
                "grams": .double(item.grams),
                "kcal": .integer(item.kcal),
                "protein_g": .double(item.proteinG),
                "carbs_g": .double(item.carbsG),
                "fat_g": .double(item.fatG),
            ]
            if let c = item.confidence { d["confidence"] = .double(c) }
            return .object(d)
        }

        let payload: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "image_path": imagePath.map { AnyJSON.string($0) } ?? .null,
            "items_json": .array(itemsJSON),
            "kcal": .integer(kcal),
            "protein_g": .double(protein),
            "carbs_g": .double(carbs),
            "fat_g": .double(fat),
            "source": .string(source.rawValue),
        ]

        try await SupabaseService.shared.from("food_logs").insert(payload).execute()
    }

    func fetchToday() async throws -> [FoodLog] {
        guard let userId = AuthService.shared.userId else { return [] }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let iso = ISO8601DateFormatter().string(from: startOfDay)
        let rows: [FoodLog] = try await SupabaseService.shared
            .from("food_logs")
            .select()
            .eq("user_id", value: userId.uuidString)
            .gte("logged_at", value: iso)
            .order("logged_at", ascending: false)
            .execute()
            .value
        return rows
    }

    func delete(id: UUID) async throws {
        try await SupabaseService.shared.from("food_logs")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
